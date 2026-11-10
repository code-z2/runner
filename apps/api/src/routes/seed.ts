import { ed25519 } from "@noble/curves/ed25519.js";
import { base58 } from "@scure/base";
import { fromBase64, toBase64, toHex, utf8 } from "../codec";
import { nowSeconds, requireSettings, type Env } from "../env";
import { HttpError, json, readJson, stringField } from "../http";
import { isAccountId, parsePublicKey, rpcCall, viewAccessKey, viewAccount } from "../near";
import { buildTransferTransaction, parseRelayerKey } from "../nearTx";
import { outcome } from "./relay";
import { checkDevice } from "./runner";

const SEEDS_PER_HOUR = 5;
const SEED_MESSAGE_PREFIX = "seed:";

interface SeederConfig {
  accountId: string;
  amount: bigint;
  enabled: boolean;
}

async function readSeeder(env: Env): Promise<SeederConfig> {
  const response = await rpcCall(env.NEAR_RPC_URL, "query", {
    request_type: "call_function",
    finality: "final",
    account_id: env.TREASURY_CONTRACT,
    method_name: "get_seeder",
    args_base64: toBase64(utf8("{}")),
  });
  const result = response.result as { result?: number[] } | undefined;
  if (!result || !Array.isArray(result.result)) {
    throw new HttpError(503, "seeder_unavailable");
  }
  let parsed: { account_id?: unknown; amount?: unknown; enabled?: unknown };
  try {
    parsed = JSON.parse(new TextDecoder().decode(new Uint8Array(result.result)));
  } catch {
    throw new HttpError(503, "seeder_unavailable");
  }
  if (typeof parsed.account_id !== "string" || !isAccountId(parsed.account_id)) {
    throw new HttpError(503, "seeder_unavailable");
  }
  let amount: bigint;
  try {
    amount = BigInt(parsed.amount as string);
  } catch {
    throw new HttpError(503, "seeder_unavailable");
  }
  if (amount <= 0n || parsed.enabled !== true) {
    throw new HttpError(503, "seeding_disabled");
  }
  return { accountId: parsed.account_id, amount, enabled: true };
}

async function sendSeedTransfer(
  env: Env,
  seeder: SeederConfig,
  accountId: string,
): Promise<string> {
  const key = parseRelayerKey(env.SEEDER_SECRET_KEY);
  const seederKey = await viewAccessKey(env.NEAR_RPC_URL, seeder.accountId, key.publicKeyText);
  if (!seederKey?.fullAccess) {
    throw new HttpError(503, "seeder_key_mismatch");
  }
  for (let attempt = 0; attempt < 2; attempt++) {
    const access = await viewAccessKey(env.NEAR_RPC_URL, seeder.accountId, key.publicKeyText);
    if (!access) {
      throw new HttpError(503, "seeder_key_mismatch");
    }
    const transaction = buildTransferTransaction({
      senderId: seeder.accountId,
      key,
      nonce: access.nonce + 1n,
      blockHash: base58.decode(access.blockHash),
      receiverId: accountId,
      amount: seeder.amount,
    });
    const response = await rpcCall(env.NEAR_RPC_URL, "send_tx", {
      signed_tx_base64: toBase64(transaction.signedTransaction),
      wait_until: "EXECUTED_OPTIMISTIC",
    });
    if (response.result) {
      const { status } = outcome(response.result);
      if (status !== "succeeded") {
        throw new HttpError(502, "seed_rejected");
      }
      return transaction.hash;
    }
    const cause = JSON.stringify(response.error ?? {});
    if (!cause.includes("InvalidNonce") || attempt === 1) {
      throw new HttpError(502, "seed_rejected");
    }
  }
  throw new HttpError(502, "seed_rejected");
}

/// Fund a missing implicit account from the DAO seeder. Idempotent: an
/// existing account returns unseeded without touching the chain. Throws
/// when seeding is disabled or the funder cannot pay.
export async function ensureSeeded(
  env: Env,
  accountId: string,
): Promise<{ seeded: boolean; txHash?: string }> {
  if (!isAccountId(accountId)) {
    throw new HttpError(400, "invalid_account_id");
  }
  if (await viewAccount(env.NEAR_RPC_URL, accountId)) {
    return { seeded: false };
  }
  const seeder = await readSeeder(env);
  const txHash = await sendSeedTransfer(env, seeder, accountId);
  await env.DB.prepare("INSERT OR IGNORE INTO seed_log (account_id, key_id, created_at) VALUES (?1, ?2, ?3)")
    .bind(accountId, null, nowSeconds())
    .run();
  return { seeded: true, txHash };
}

export async function seedAccount(request: Request, env: Env): Promise<Response> {
  requireSettings(env, ["APP_ID", "NEAR_RPC_URL", "TREASURY_CONTRACT", "SEEDER_SECRET_KEY"]);
  const body = await readJson(request);
  const accountId = stringField(body, "account_id", 64).toLowerCase();
  const keyId = stringField(body, "key_id", 64);
  const assertion = fromBase64(stringField(body, "assertion", 4096), "invalid_assertion");
  const nearPublicKeyText = stringField(body, "near_public_key", 128);
  const nearSignature = fromBase64(stringField(body, "near_signature", 128), "invalid_near_signature");

  if (!isAccountId(accountId)) {
    throw new HttpError(400, "invalid_account_id");
  }
  const publicKey = parsePublicKey(nearPublicKeyText);
  if (toHex(publicKey) !== accountId) {
    throw new HttpError(400, "not_implicit_account");
  }
  if (nearSignature.length !== 64) {
    throw new HttpError(400, "invalid_near_signature");
  }
  const message = utf8(`${SEED_MESSAGE_PREFIX}${accountId}`);
  let signed = false;
  try {
    signed = ed25519.verify(nearSignature, message, publicKey);
  } catch {
    signed = false;
  }
  if (!signed) {
    throw new HttpError(401, "invalid_near_signature");
  }
  await checkDevice(env, keyId, assertion, `${SEED_MESSAGE_PREFIX}${accountId}`);

  const recent = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM seed_log WHERE key_id = ?1 AND created_at > ?2",
  )
    .bind(keyId, nowSeconds() - 3600)
    .first<{ count: number }>();
  if ((recent?.count ?? 0) >= SEEDS_PER_HOUR) {
    throw new HttpError(429, "too_many_requests");
  }

  const result = await ensureSeeded(env, accountId);
  if (result.seeded) {
    await env.DB.prepare("UPDATE seed_log SET key_id = ?1 WHERE account_id = ?2")
      .bind(keyId, accountId)
      .run();
  }
  return json({ seeded: result.seeded, ...(result.txHash ? { tx: result.txHash } : {}) }, 200);
}
