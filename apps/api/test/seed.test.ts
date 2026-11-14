import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { ed25519 } from "@noble/curves/ed25519.js";
import { p256 } from "@noble/curves/nist.js";
import { base58 } from "@scure/base";
import { handle } from "../src/index";
import { toBase64, toHex, utf8 } from "../src/codec";
import type { Env } from "../src/env";
import { nep413Digest } from "../src/near";
import { createEnv, makeAssertion, stubFetch } from "./support";

const base = "https://api.runner.test";

function call(env: Env, method: string, path: string, body?: unknown): Promise<Response> {
  const headers: Record<string, string> = {};
  if (body !== undefined) headers["content-type"] = "application/json";
  return handle(
    new Request(`${base}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) }),
    env,
  );
}

interface Rpc {
  existingAccounts: Set<string>;
  seederEnabled: boolean;
  sent: unknown[];
}

function stubServices(rpc: Rpc): () => void {
  return stubFetch(async (url, init) => {
    const body = JSON.parse(String(init.body));
    if (body.method === "send_tx") {
      rpc.sent.push(body);
      return Response.json({
        result: {
          status: { SuccessValue: "" },
          transaction: { hash: "seed-tx" },
          transaction_outcome: { id: "seed-tx", outcome: { status: { SuccessValue: "" }, logs: [], gas_burnt: 1 } },
          receipts_outcome: [],
        },
      });
    }
    const params = body.params;
    if (params.request_type === "view_account") {
      return rpc.existingAccounts.has(params.account_id)
        ? Response.json({ result: { amount: "1000000", locked: "0" } })
        : Response.json({ error: { name: "HANDLER_ERROR", cause: { name: "UNKNOWN_ACCOUNT" } } });
    }
    if (params.request_type === "view_access_key") {
      return Response.json({
        result: { nonce: 7, permission: "FullAccess", block_hash: "11111111111111111111111111111111", block_height: 100 },
      });
    }
    return Response.json({
      result: {
        result: Array.from(
          utf8(JSON.stringify({ account_id: "seeder.ije.near", amount: "5000000000000000000000", enabled: rpc.seederEnabled })),
        ),
        logs: [],
      },
    });
  });
}

function parseTransfer(sent: Record<string, unknown>): { receiver: string; amount: bigint } {
  const params = sent.params as Record<string, string>;
  const tx = Buffer.from(params.signed_tx_base64, "base64");
  let offset = 0;
  const readString = (): string => {
    const length = tx.readUInt32LE(offset);
    offset += 4;
    const text = tx.toString("utf8", offset, offset + length);
    offset += length;
    return text;
  };
  readString();
  offset += 33;
  offset += 8;
  const receiver = readString();
  offset += 32;
  offset += 4;
  const tag = tx.readUInt8(offset);
  offset += 1;
  const amount = tx.readBigUInt64LE(offset) | (tx.readBigUInt64LE(offset + 8) << 64n);
  expect(tag).toBe(3);
  return { receiver, amount };
}

describe("seeding", () => {
  let env: Env;
  let rpc: Rpc;
  let restore: () => void;
  const deviceSecret = p256.utils.randomSecretKey();
  const keyId = toBase64(new Uint8Array(32).fill(9));
  const seederSecret = ed25519.utils.randomSecretKey();
  let counter = 0;

  beforeEach(async () => {
    env = createEnv({
      SEEDER_SECRET_KEY: `ed25519:${base58.encode(Buffer.concat([seederSecret, ed25519.getPublicKey(seederSecret)]))}`,
    });
    rpc = { existingAccounts: new Set(), seederEnabled: true, sent: [] };
    restore = stubServices(rpc);
    counter = 0;
    await env.DB.prepare("INSERT INTO devices (key_id, public_key, counter, created_at) VALUES (?, ?, 0, 0)")
      .bind(keyId, toBase64(p256.getPublicKey(deviceSecret, false)))
      .run();
  });

  afterEach(() => restore());

  function freshAccount(): { accountId: string; secret: Uint8Array } {
    const secret = ed25519.utils.randomSecretKey();
    return { accountId: toHex(ed25519.getPublicKey(secret)), secret };
  }

  async function seed(accountId: string, secret: Uint8Array, publicKey?: Uint8Array): Promise<Response> {
    const clientData = `seed:${accountId}`;
    counter += 1;
    return call(env, "POST", "/v1/seed", {
      account_id: accountId,
      key_id: keyId,
      assertion: toBase64(makeAssertion(deviceSecret, utf8(clientData), counter)),
      near_public_key: `ed25519:${base58.encode(publicKey ?? ed25519.getPublicKey(secret))}`,
      near_signature: toBase64(ed25519.sign(utf8(clientData), secret)),
    });
  }

  test("seeds a missing implicit account", async () => {
    const { accountId, secret } = freshAccount();
    const response = await seed(accountId, secret);
    expect(response.status).toBe(200);
    const seeded = (await response.json()) as { seeded: boolean; tx?: string };
    expect(seeded.seeded).toBe(true);
    expect(typeof seeded.tx).toBe("string");
    expect(rpc.sent.length).toBe(1);
    expect(parseTransfer(rpc.sent[0] as Record<string, unknown>)).toEqual({
      receiver: accountId,
      amount: 5_000_000_000_000_000_000_000n,
    });
  });

  test("leaves existing accounts untouched", async () => {
    const { accountId, secret } = freshAccount();
    rpc.existingAccounts.add(accountId);
    const response = await seed(accountId, secret);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ seeded: false });
    expect(rpc.sent.length).toBe(0);
  });

  test("refuses a signature from another key", async () => {
    const { accountId, secret } = freshAccount();
    const other = ed25519.utils.randomSecretKey();
    const response = await seed(accountId, other, ed25519.getPublicKey(secret));
    expect(response.status).toBe(401);
    expect(rpc.sent.length).toBe(0);
  });

  test("refuses named accounts", async () => {
    const secret = ed25519.utils.randomSecretKey();
    const response = await seed("someone.near", secret);
    expect(response.status).toBe(400);
    expect(rpc.sent.length).toBe(0);
  });

  test("fails closed when the DAO disables seeding", async () => {
    rpc.seederEnabled = false;
    const { accountId, secret } = freshAccount();
    const response = await seed(accountId, secret);
    expect(response.status).toBe(503);
    expect(rpc.sent.length).toBe(0);
  });

  test("rate limits seeds per device", async () => {
    for (let index = 0; index < 5; index++) {
      const { accountId, secret } = freshAccount();
      expect((await seed(accountId, secret)).status).toBe(200);
    }
    const { accountId, secret } = freshAccount();
    const response = await seed(accountId, secret);
    expect(response.status).toBe(429);
    expect(await response.json()).toEqual({ error: "too_many_requests" });
    expect(rpc.sent.length).toBe(5);
  });

  test("the proof path authenticates an implicit key without seeding before the first transaction", async () => {
    const secret = ed25519.utils.randomSecretKey();
    const accountId = toHex(ed25519.getPublicKey(secret));
    const { challenge } = (await (await call(env, "POST", "/v1/challenge")).json()) as { challenge: string };
    const ended = Math.floor(Date.now() / 1000) - 600;
    const activity = {
      id: crypto.randomUUID(), started_at: ended - 1800, ended_at: ended, distance_m: 5120,
      active_seconds: 1800, km_splits_s: [350, 352, 348, 351, 349], steps: 5400,
    };
    const payload = JSON.stringify({ account_id: accountId, challenge, activity });
    counter += 1;
    const nonce = Buffer.from(challenge, "base64");
    const response = await call(env, "POST", "/v1/attestations", {
      payload,
      key_id: keyId,
      assertion: toBase64(makeAssertion(deviceSecret, utf8(payload), counter)),
      near_public_key: `ed25519:${base58.encode(ed25519.getPublicKey(secret))}`,
      near_signature: toBase64(ed25519.sign(nep413Digest(payload, nonce, "runner-api"), secret)),
    });
    expect(rpc.sent.length).toBe(0);
    expect(response.status).toBe(201);
  });
});
