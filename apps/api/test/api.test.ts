import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { ed25519 } from "@noble/curves/ed25519.js";
import { p256 } from "@noble/curves/nist.js";
import { base58 } from "@scure/base";
import { cleanup, handle } from "../src/index";
import { toBase64, utf8 } from "../src/codec";
import { nowSeconds, type Env } from "../src/env";
import { nep413Digest } from "../src/near";
import { geohash } from "../src/geohash";
import { createEnv, makeAssertion, stubFetch } from "./support";

const base = "https://api.runner.test";

function call(env: Env, method: string, path: string, body?: unknown, token?: string): Promise<Response> {
  const headers: Record<string, string> = {};
  if (body !== undefined) headers["content-type"] = "application/json";
  if (token) headers.authorization = `Bearer ${token}`;
  return handle(
    new Request(`${base}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) }),
    env,
  );
}

interface Rpc {
  fullAccessKeys: Set<string>;
  merchants: Set<string>;
  mail: { to: string[]; text: string }[];
}

function stubServices(rpc: Rpc): () => void {
  return stubFetch(async (url, init) => {
    const body = JSON.parse(String(init.body));
    if (url === "https://api.resend.com/emails") {
      rpc.mail.push(body);
      return Response.json({ id: "email-1" });
    }
    const params = body.params;
    if (params.request_type === "view_access_key") {
      return rpc.fullAccessKeys.has(`${params.account_id}/${params.public_key}`)
        ? Response.json({ result: { nonce: 1, permission: "FullAccess", block_hash: "11111111111111111111111111111111", block_height: 100 } })
        : Response.json({ result: { error: "access key does not exist" } });
    }
    const args = JSON.parse(Buffer.from(params.args_base64, "base64").toString());
    const registered = params.account_id === "treasury.runner.near" && rpc.merchants.has(args.account_id);
    return Response.json({ result: { result: Array.from(utf8(JSON.stringify(registered))), logs: [] } });
  });
}

describe("runner flow", () => {
  let env: Env;
  let rpc: Rpc;
  let restore: () => void;
  const deviceSecret = p256.utils.randomSecretKey();
  const keyId = toBase64(new Uint8Array(32).fill(3));
  const nearSecret = ed25519.utils.randomSecretKey();
  const nearPublicKey = `ed25519:${base58.encode(ed25519.getPublicKey(nearSecret))}`;
  let counter = 0;

  beforeEach(async () => {
    env = createEnv();
    rpc = { fullAccessKeys: new Set([`runner.near/${nearPublicKey}`]), merchants: new Set(), mail: [] };
    restore = stubServices(rpc);
    counter = 0;
    await env.DB.prepare("INSERT INTO devices (key_id, public_key, counter, created_at) VALUES (?, ?, 0, 0)")
      .bind(keyId, toBase64(p256.getPublicKey(deviceSecret, false)))
      .run();
  });

  afterEach(() => restore());

  async function attest(activity: Record<string, unknown>, accountId = "runner.near"): Promise<Response> {
    const { challenge } = (await (await call(env, "POST", "/v1/challenge")).json()) as { challenge: string };
    const payload = JSON.stringify({ account_id: accountId, challenge, activity });
    counter += 1;
    const nonce = Buffer.from(challenge, "base64");
    return call(env, "POST", "/v1/attestations", {
      payload,
      key_id: keyId,
      assertion: toBase64(makeAssertion(deviceSecret, utf8(payload), counter)),
      near_public_key: nearPublicKey,
      near_signature: toBase64(ed25519.sign(nep413Digest(payload, nonce, "runner-api"), nearSecret)),
    });
  }

  function activity(endedAgo: number, id = crypto.randomUUID()): Record<string, unknown> {
    const ended = nowSeconds() - endedAgo;
    return {
      id,
      started_at: ended - 1800,
      ended_at: ended,
      active_seconds: 1800,
      distance_m: 5120,
      km_splits_s: [350, 352, 348, 351, 349],
      steps: 5400,
    };
  }

  test("issues a signed claim pass for an eligible run", async () => {
    const response = await attest(activity(600));
    expect(response.status).toBe(201);
    const body = (await response.json()) as { attestation: string; signature: string };
    const pass = JSON.parse(body.attestation);
    expect(pass.account_id).toBe("runner.near");
    expect(pass.max_amount_cents).toBe(256);
    expect(pass.expires_at - nowSeconds()).toBeGreaterThan(7190);
    const attestorPublic = ed25519.getPublicKey(Buffer.from(env.ATTESTOR_SECRET_KEY, "base64"));
    expect(ed25519.verify(Buffer.from(body.signature, "base64"), utf8(body.attestation), attestorPublic)).toBe(true);
  });

  test("also signs a run proof the goal escrow can check", async () => {
    const run = activity(600);
    const body = (await (await attest(run)).json()) as { run_proof: string; run_proof_signature: string };
    const proof = JSON.parse(body.run_proof);
    expect(Object.keys(proof)).toEqual(["v", "kind", "account_id", "activity_hash", "started_at", "ended_at", "distance_m", "active_seconds"]);
    expect(proof).toMatchObject({ v: 1, kind: "run", account_id: "runner.near", distance_m: 5120, active_seconds: 1800, started_at: run.started_at });
    const attestorPublic = ed25519.getPublicKey(Buffer.from(env.ATTESTOR_SECRET_KEY, "base64"));
    expect(ed25519.verify(Buffer.from(body.run_proof_signature, "base64"), utf8(body.run_proof), attestorPublic)).toBe(true);
  });

  test("refuses a second run within 4 hours", async () => {
    expect((await attest(activity(10000))).status).toBe(201);
    const second = await attest(activity(600));
    expect(second.status).toBe(409);
    expect(await second.json()).toEqual({ error: "too_soon" });
  });

  test("refuses the same run twice", async () => {
    const run = activity(600);
    expect((await attest(run)).status).toBe(201);
    expect((await attest(run)).status).toBe(409);
  });

  test("refuses a key that is not a full access key on the account", async () => {
    const response = await attest(activity(600), "someone.near");
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "invalid_near_signature" });
  });

  test("explains why a run is not eligible", async () => {
    const response = await attest({ ...activity(600), distance_m: 2000, km_splits_s: [350, 350] });
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "too_short" });
  });

  test("uses each challenge once", async () => {
    const { challenge } = (await (await call(env, "POST", "/v1/challenge")).json()) as { challenge: string };
    const payload = JSON.stringify({ account_id: "runner.near", challenge, activity: activity(600) });
    const nonce = Buffer.from(challenge, "base64");
    const request = (count: number) =>
      call(env, "POST", "/v1/attestations", {
        payload,
        key_id: keyId,
        assertion: toBase64(makeAssertion(deviceSecret, utf8(payload), count)),
        near_public_key: nearPublicKey,
        near_signature: toBase64(ed25519.sign(nep413Digest(payload, nonce, "runner-api"), nearSecret)),
      });
    expect((await request(1)).status).toBe(201);
    const replay = await request(2);
    expect(replay.status).toBe(400);
    expect(await replay.json()).toEqual({ error: "invalid_challenge" });
  });

  test("refuses unknown devices", async () => {
    await env.DB.prepare("DELETE FROM devices").run();
    const response = await attest(activity(600));
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unknown_device" });
  });

  test("cleanup removes expired challenges and old runs", async () => {
    await env.DB.prepare("INSERT INTO challenges (id, expires_at) VALUES ('old', 1)").run();
    await env.DB.prepare(
      "INSERT INTO attested_activities (activity_hash, account_id, key_id, started_at, ended_at, created_at) VALUES ('h', 'a.near', 'k', 1, 2, 2)",
    ).run();
    await cleanup(env);
    expect(await env.DB.prepare("SELECT 1 FROM challenges WHERE id = 'old'").first()).toBeNull();
    expect(await env.DB.prepare("SELECT 1 FROM attested_activities").first()).toBeNull();
  });
});

describe("merchant and admin flow", () => {
  let env: Env;
  let rpc: Rpc;
  let restore: () => void;

  beforeEach(() => {
    env = createEnv();
    rpc = { fullAccessKeys: new Set(), merchants: new Set(), mail: [] };
    restore = stubServices(rpc);
  });

  afterEach(() => restore());

  async function signIn(email: string): Promise<string> {
    expect((await call(env, "POST", "/v1/merchant/login", { email })).status).toBe(202);
    const token = rpc.mail.at(-1)!.text.match(/#token=([0-9a-f]{64})/)![1];
    const response = await call(env, "POST", "/v1/merchant/session", { token });
    expect(response.status).toBe(201);
    return ((await response.json()) as { session: string }).session;
  }

  const shop = {
    name: "Mama Put",
    address: "12 Allen Avenue, Ikeja, Lagos",
    lat: 6.6018,
    lng: 3.3515,
    categories: ["water", "meals"],
    near_account: "mamaput.near",
  };

  test("sign-in links work once and are rate limited", async () => {
    await call(env, "POST", "/v1/merchant/login", { email: "Shop@Example.com" });
    await call(env, "POST", "/v1/merchant/login", { email: "shop@example.com" });
    expect(rpc.mail).toHaveLength(1);
    expect(rpc.mail[0].to).toEqual(["shop@example.com"]);
    const token = rpc.mail[0].text.match(/#token=([0-9a-f]{64})/)![1];
    expect((await call(env, "POST", "/v1/merchant/session", { token })).status).toBe(201);
    expect((await call(env, "POST", "/v1/merchant/session", { token })).status).toBe(401);
  });

  test("a location shows in discovery only after onchain registration and approval", async () => {
    const session = await signIn("shop@example.com");
    const created = await call(env, "POST", "/v1/merchant/locations", shop, session);
    expect(created.status).toBe(201);
    const { location } = (await created.json()) as { location: { id: string; status: string } };
    expect(location.status).toBe("pending");

    const cells = `/v1/merchants?cells=${geohash(shop.lat, shop.lng)},s14eu`;
    expect(((await (await call(env, "GET", cells)).json()) as { locations: unknown[] }).locations).toHaveLength(0);

    const admin = await signIn("admin@runner.test");
    expect((await call(env, "GET", "/v1/admin/locations", undefined, admin)).status).toBe(403);
    await env.DB.prepare("UPDATE merchants SET is_admin = 1 WHERE email = 'admin@runner.test'").run();

    const pending = await call(env, "GET", "/v1/admin/locations?status=pending", undefined, admin);
    expect(((await pending.json()) as { locations: unknown[] }).locations).toHaveLength(1);

    const early = await call(env, "POST", `/v1/admin/locations/${location.id}/approve`, undefined, admin);
    expect(early.status).toBe(409);
    expect(await early.json()).toEqual({ error: "not_registered_onchain" });

    rpc.merchants.add("mamaput.near");
    expect((await call(env, "POST", `/v1/admin/locations/${location.id}/approve`, undefined, admin)).status).toBe(200);

    const listed = (await (await call(env, "GET", cells)).json()) as { locations: { name: string }[] };
    expect(listed.locations.map((entry) => entry.name)).toEqual(["Mama Put"]);
  });

  test("changing the payout account sends a location back for review", async () => {
    const session = await signIn("shop@example.com");
    const { location } = (await (await call(env, "POST", "/v1/merchant/locations", shop, session)).json()) as {
      location: { id: string };
    };
    await env.DB.prepare("UPDATE locations SET status = 'approved'").run();

    const renamed = await call(env, "PATCH", `/v1/merchant/locations/${location.id}`, { name: "Mama Put 2" }, session);
    expect(((await renamed.json()) as { location: { status: string } }).location.status).toBe("approved");

    const moved = await call(
      env,
      "PATCH",
      `/v1/merchant/locations/${location.id}`,
      { near_account: "newwallet.near" },
      session,
    );
    expect(((await moved.json()) as { location: { status: string } }).location.status).toBe("pending");
  });

  test("merchants cannot edit each other's locations", async () => {
    const owner = await signIn("shop@example.com");
    const other = await signIn("other@example.com");
    const { location } = (await (await call(env, "POST", "/v1/merchant/locations", shop, owner)).json()) as {
      location: { id: string };
    };
    const response = await call(env, "PATCH", `/v1/merchant/locations/${location.id}`, { name: "Mine" }, other);
    expect(response.status).toBe(404);
  });

  test("water is a required category", async () => {
    const session = await signIn("shop@example.com");
    const response = await call(env, "POST", "/v1/merchant/locations", { ...shop, categories: ["meals"] }, session);
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_categories" });
  });

  test("portal routes answer CORS preflight for the portal origin only", async () => {
    const response = await handle(new Request(`${base}/v1/merchant/locations`, { method: "OPTIONS" }), env);
    expect(response.status).toBe(204);
    expect(response.headers.get("access-control-allow-origin")).toBe("https://portal.runner.test");
  });

  test("each feature needs only its own settings", async () => {
    const partial = createEnv({ ATTESTOR_SECRET_KEY: "", RESEND_API_KEY: "" });
    expect((await call(partial, "POST", "/v1/challenge")).status).toBe(201);
    expect((await call(partial, "GET", "/v1/merchants?cells=s14eu")).status).toBe(200);
    const login = await call(partial, "POST", "/v1/merchant/login", { email: "shop@example.com" });
    expect(login.status).toBe(503);
    expect(await login.json()).toEqual({ error: "misconfigured" });
  });
});
