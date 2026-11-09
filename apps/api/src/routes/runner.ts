import { verifyAssertion, verifyKeyAttestation } from "../appAttest";
import { attestorSecret, signClaimPass, signRunProof } from "../attestor";
import { fromBase64, hashHex, randomBytes, toBase64, utf8 } from "../codec";
import { CLAIM_WINDOW_S, GAP_S, checkEligibility, maxAmountCents, parseActivity } from "../eligibility";
import { nowSeconds, requireSettings, type Env } from "../env";
import { isCell } from "../geohash";
import { HttpError, json, parseObject, readJson, stringField } from "../http";
import { isAccountId, isFullAccessKey, parsePublicKey, verifyNep413 } from "../near";

const CHALLENGE_TTL_S = 300;
const MAX_CELLS = 9;

export async function createChallenge(env: Env): Promise<Response> {
  const challenge = toBase64(randomBytes(32));
  await env.DB.prepare("INSERT INTO challenges (id, expires_at) VALUES (?, ?)")
    .bind(challenge, nowSeconds() + CHALLENGE_TTL_S)
    .run();
  return json({ challenge }, 201);
}

async function consumeChallenge(env: Env, challenge: string): Promise<Uint8Array> {
  const bytes = fromBase64(challenge, "invalid_challenge");
  const result = await env.DB.prepare("DELETE FROM challenges WHERE id = ? AND expires_at > ?")
    .bind(challenge, nowSeconds())
    .run();
  if (bytes.length !== 32 || result.meta.changes !== 1) {
    throw new HttpError(400, "invalid_challenge");
  }
  return bytes;
}

export async function registerDevice(request: Request, env: Env): Promise<Response> {
  requireSettings(env, ["APP_ID", "APP_ATTEST_ENV"]);
  const body = await readJson(request);
  const keyId = stringField(body, "key_id", 64);
  const attestation = fromBase64(stringField(body, "attestation", 12000), "invalid_attestation");
  const keyIdBytes = fromBase64(keyId, "invalid_key_id");
  const challenge = await consumeChallenge(env, stringField(body, "challenge", 64));
  const publicKey = await verifyKeyAttestation({
    attestation,
    challenge,
    keyId: keyIdBytes,
    appId: env.APP_ID,
    environment: env.APP_ATTEST_ENV,
    now: new Date(),
  });
  const result = await env.DB.prepare(
    "INSERT OR IGNORE INTO devices (key_id, public_key, counter, created_at) VALUES (?, ?, 0, ?)",
  )
    .bind(keyId, toBase64(publicKey), nowSeconds())
    .run();
  if (result.meta.changes !== 1) {
    throw new HttpError(409, "device_exists");
  }
  return json({ key_id: keyId }, 201);
}

async function checkDevice(env: Env, keyId: string, assertion: Uint8Array, payload: string): Promise<void> {
  const device = await env.DB.prepare("SELECT public_key, counter FROM devices WHERE key_id = ?")
    .bind(keyId)
    .first<{ public_key: string; counter: number }>();
  if (!device) {
    throw new HttpError(401, "unknown_device");
  }
  const counter = verifyAssertion({
    assertion,
    clientData: utf8(payload),
    publicKey: fromBase64(device.public_key, "invalid_device"),
    previousCounter: device.counter,
    appId: env.APP_ID,
  });
  const update = await env.DB.prepare("UPDATE devices SET counter = ? WHERE key_id = ? AND counter < ?")
    .bind(counter, keyId, counter)
    .run();
  if (update.meta.changes !== 1) {
    throw new HttpError(401, "invalid_assertion");
  }
}

export async function createAttestation(request: Request, env: Env): Promise<Response> {
  requireSettings(env, ["APP_ID", "NEAR_RPC_URL", "NEAR_RECIPIENT", "ATTESTOR_SECRET_KEY"]);
  const body = await readJson(request);
  const payload = stringField(body, "payload", 8192);
  const keyId = stringField(body, "key_id", 64);
  const assertion = fromBase64(stringField(body, "assertion", 4096), "invalid_assertion");
  const nearPublicKeyText = stringField(body, "near_public_key", 128);
  const nearPublicKey = parsePublicKey(nearPublicKeyText);
  const nearSignature = stringField(body, "near_signature", 128);

  const content = parseObject(payload, "invalid_payload");
  const accountId = stringField(content, "account_id", 64);
  if (!isAccountId(accountId)) {
    throw new HttpError(400, "invalid_account_id");
  }
  const activity = parseActivity(content.activity);
  const challenge = await consumeChallenge(env, stringField(content, "challenge", 64));

  await checkDevice(env, keyId, assertion, payload);
  const signed = verifyNep413({
    message: payload,
    nonce: challenge,
    recipient: env.NEAR_RECIPIENT,
    publicKey: nearPublicKey,
    signature: nearSignature,
  });
  if (!signed || !(await isFullAccessKey(env.NEAR_RPC_URL, accountId, nearPublicKeyText))) {
    throw new HttpError(401, "invalid_near_signature");
  }

  const now = nowSeconds();
  checkEligibility(activity, now);

  const activityHash = hashHex(
    utf8(`${accountId}|${activity.id}|${activity.startedAt}|${activity.endedAt}|${activity.distanceM}`),
  );
  const insert = await env.DB.prepare(
    `INSERT OR IGNORE INTO attested_activities (activity_hash, account_id, key_id, started_at, ended_at, created_at)
     SELECT ?1, ?2, ?3, ?4, ?5, ?6
     WHERE NOT EXISTS (
       SELECT 1 FROM attested_activities
       WHERE (account_id = ?2 OR key_id = ?3) AND started_at < ?5 + ?7 AND ?4 < ended_at + ?7
     )`,
  )
    .bind(activityHash, accountId, keyId, activity.startedAt, activity.endedAt, now, GAP_S)
    .run();
  if (insert.meta.changes !== 1) {
    throw new HttpError(409, "too_soon");
  }

  const secret = attestorSecret(env.ATTESTOR_SECRET_KEY);
  const pass = signClaimPass(
    {
      accountId,
      activityHash,
      maxAmountCents: maxAmountCents(activity.distanceM),
      expiresAt: now + CLAIM_WINDOW_S,
    },
    secret,
  );
  const run = signRunProof(
    {
      accountId,
      activityHash,
      startedAt: activity.startedAt,
      endedAt: activity.endedAt,
      distanceM: activity.distanceM,
      activeSeconds: activity.activeSeconds,
    },
    secret,
  );
  return json({ ...pass, run_proof: run.attestation, run_proof_signature: run.signature }, 201);
}

export async function listMerchants(url: URL, env: Env): Promise<Response> {
  const cells = (url.searchParams.get("cells") ?? "").split(",").filter((cell) => cell.length > 0);
  if (cells.length === 0 || cells.length > MAX_CELLS || !cells.every(isCell)) {
    throw new HttpError(400, "invalid_cells");
  }
  const placeholders = cells.map(() => "?").join(", ");
  const { results } = await env.DB.prepare(
    `SELECT id, name, lat, lng, categories, near_account FROM locations
     WHERE status = 'approved' AND geohash5 IN (${placeholders})
     ORDER BY id`,
  )
    .bind(...cells)
    .all<{ id: string; name: string; lat: number; lng: number; categories: string; near_account: string }>();
  const locations = results.map((row) => ({ ...row, categories: JSON.parse(row.categories) as string[] }));
  return json({ locations }, 200, { "cache-control": "public, max-age=600" });
}
