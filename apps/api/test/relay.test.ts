import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { ed25519 } from "@noble/curves/ed25519.js";
import { p256 } from "@noble/curves/nist.js";
import { base58 } from "@scure/base";
import { hash, toBase64, utf8 } from "../src/codec";
import { nowSeconds, type Env } from "../src/env";
import { handle } from "../src/index";
import {
  decodeSignedDelegate,
  delegateDigest,
  encodeDelegateAction,
  encodeSignedDelegate,
  type DelegateAction,
} from "../src/nearTx";
import { createEnv, makeAssertion, stubFetch } from "./support";

const userSecret = ed25519.utils.randomSecretKey();
const userPublic = ed25519.getPublicKey(userSecret);
const userKeyText = `ed25519:${base58.encode(userPublic)}`;
const relayerSecret = ed25519.utils.randomSecretKey();
const relayerPublic = ed25519.getPublicKey(relayerSecret);
const relayerKeyText = `ed25519:${base58.encode(relayerPublic)}`;
const deviceSecret = p256.utils.randomSecretKey();
const keyId = toBase64(new Uint8Array(32).fill(4));
const zeroHash = "11111111111111111111111111111111";

interface Sent {
  bytes: Uint8Array;
}

function delegateFor(overrides: Partial<DelegateAction> = {}, call: Partial<DelegateAction["actions"][0]> = {}): DelegateAction {
  return {
    senderId: "runner.ije.near",
    receiverId: "escrow.ije.near",
    actions: [
      {
        methodName: "give_up",
        args: utf8(JSON.stringify({ lock_id: "0" })),
        gas: 30_000_000_000_000n,
        deposit: 1n,
        ...call,
      },
    ],
    nonce: 2n,
    maxBlockHeight: 150n,
    publicKey: userPublic,
    ...overrides,
  };
}

function signDelegate(delegate: DelegateAction, secret = userSecret): string {
  const signature = ed25519.sign(delegateDigest(encodeDelegateAction(delegate)), secret);
  return toBase64(encodeSignedDelegate(delegate, signature));
}

describe("delegate encoding", () => {
  test("round-trips a signed delegate action", () => {
    const delegate = delegateFor();
    const decoded = decodeSignedDelegate(Buffer.from(signDelegate(delegate), "base64"));
    expect(decoded.delegate.senderId).toBe("runner.ije.near");
    expect(decoded.delegate.actions[0].methodName).toBe("give_up");
    expect(decoded.delegate.actions[0].deposit).toBe(1n);
    expect(decoded.delegate.nonce).toBe(2n);
  });

  test("rejects trailing bytes", () => {
    const bytes = Buffer.concat([Buffer.from(signDelegate(delegateFor()), "base64"), Buffer.from([0])]);
    expect(() => decodeSignedDelegate(bytes)).toThrow("invalid_delegate");
  });
});

describe("POST /v1/relay", () => {
  let env: Env;
  let restore: () => void;
  let counter = 0;
  let sent: Sent[] = [];
  let nonceFailures = 0;

  beforeEach(async () => {
    env = createEnv({ RELAYER_SECRET_KEY: `ed25519:${base58.encode(new Uint8Array([...relayerSecret, ...relayerPublic]))}` });
    counter = 0;
    sent = [];
    nonceFailures = 0;
    await env.DB.prepare("INSERT INTO devices (key_id, public_key, counter, created_at) VALUES (?, ?, 0, 0)")
      .bind(keyId, toBase64(p256.getPublicKey(deviceSecret, false)))
      .run();
    restore = stubFetch(async (_url, init) => {
      const body = JSON.parse(String(init.body));
      if (body.method === "query") {
        const { account_id: account, public_key: key } = body.params;
        if (account === "runner.ije.near" && key === userKeyText) {
          return Response.json({ result: { nonce: 1, permission: "FullAccess", block_hash: zeroHash, block_height: 100 } });
        }
        if (account === "relayer.ije.near" && key === relayerKeyText) {
          return Response.json({ result: { nonce: 5, permission: "FullAccess", block_hash: zeroHash, block_height: 100 } });
        }
        return Response.json({ result: { error: "access key does not exist" } });
      }
      if (body.method === "send_tx") {
        if (nonceFailures > 0) {
          nonceFailures -= 1;
          return Response.json({ error: { name: "HANDLER_ERROR", cause: { info: { error: "InvalidNonce" } } } }, { status: 400 });
        }
        sent.push({ bytes: Buffer.from(body.params.signed_tx_base64, "base64") });
        return Response.json({ result: { status: { SuccessValue: "" }, receipts_outcome: [] } });
      }
      return Response.json({ error: { name: "UNKNOWN" } }, { status: 400 });
    });
  });

  afterEach(() => restore());

  function post(signedDelegate: string): Promise<Response> {
    counter += 1;
    return handle(
      new Request("https://api.runner.test/v1/relay", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          signed_delegate: signedDelegate,
          key_id: keyId,
          assertion: toBase64(makeAssertion(deviceSecret, utf8(signedDelegate), counter)),
        }),
      }),
      env,
    );
  }

  test("wraps an allowed call, signs it as the relayer and reports the outcome", async () => {
    const signedDelegate = signDelegate(delegateFor());
    const response = await post(signedDelegate);
    expect(response.status).toBe(200);
    const result = (await response.json()) as { transaction_hash: string; status: string };
    expect(result.status).toBe("succeeded");
    expect(sent).toHaveLength(1);

    const tx = sent[0].bytes;
    const delegateBytes = Buffer.from(signedDelegate, "base64");
    const transaction = tx.slice(0, tx.length - 65);
    const signature = tx.slice(tx.length - 64);
    expect(ed25519.verify(signature, hash(transaction), relayerPublic)).toBe(true);
    expect(result.transaction_hash).toBe(base58.encode(hash(transaction)));
    expect(Buffer.from(transaction.slice(transaction.length - delegateBytes.length)).equals(delegateBytes)).toBe(true);
    expect(transaction[transaction.length - delegateBytes.length - 1]).toBe(8);
    const nonceOffset = 4 + "relayer.ije.near".length + 33;
    expect(new DataView(transaction.buffer, transaction.byteOffset).getBigUint64(nonceOffset, true)).toBe(6n);
  });

  test("lets a runner lock a goal through the token contract", async () => {
    const delegate = delegateFor(
      { receiverId: "usdc.near" },
      {
        methodName: "ft_transfer_call",
        args: utf8(JSON.stringify({ receiver_id: "escrow.ije.near", amount: "25000000", msg: "{\"distance_m\":10000}" })),
      },
    );
    expect((await post(signDelegate(delegate))).status).toBe(200);
  });

  test("refuses token transfers to anyone but the escrow or treasury", async () => {
    const delegate = delegateFor(
      { receiverId: "usdc.near" },
      { methodName: "ft_transfer_call", args: utf8(JSON.stringify({ receiver_id: "thief.near", amount: "1", msg: "" })) },
    );
    const response = await post(signDelegate(delegate));
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "call_not_allowed" });
  });

  test("refuses methods outside the allow-list", async () => {
    const response = await post(signDelegate(delegateFor({}, { methodName: "set_owner", deposit: 0n })));
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "call_not_allowed" });
  });

  test("refuses a deposit other than the one the method needs", async () => {
    const response = await post(signDelegate(delegateFor({}, { deposit: 0n })));
    expect(await response.json()).toEqual({ error: "deposit_not_allowed" });
  });

  test("lets a claim through the DAO use up to 300 Tgas", async () => {
    const delegate = delegateFor(
      { receiverId: "treasury.ije.near" },
      { methodName: "claim", args: utf8(JSON.stringify({ attestation: "{}", signature: "", merchant_id: "mamaput.near", amount_cents: 100 })), gas: 250_000_000_000_000n, deposit: 0n },
    );
    expect((await post(signDelegate(delegate))).status).toBe(200);
  });

  test("refuses a claim above 300 Tgas", async () => {
    const delegate = delegateFor(
      { receiverId: "treasury.ije.near" },
      { methodName: "claim", args: utf8(JSON.stringify({ attestation: "{}", signature: "", merchant_id: "mamaput.near", amount_cents: 100 })), gas: 301_000_000_000_000n, deposit: 0n },
    );
    const response = await post(signDelegate(delegate));
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "gas_not_allowed" });
  });

  test("lets anyone donate to the DAO pool with a plain transfer", async () => {
    const delegate = delegateFor(
      { receiverId: "usdc.near" },
      { methodName: "ft_transfer", args: utf8(JSON.stringify({ receiver_id: "ije.sputnik-dao.near", amount: "5000000" })), gas: 10_000_000_000_000n },
    );
    expect((await post(signDelegate(delegate))).status).toBe(200);
  });

  test("refuses plain transfers to anyone but the DAO", async () => {
    const delegate = delegateFor(
      { receiverId: "usdc.near" },
      { methodName: "ft_transfer", args: utf8(JSON.stringify({ receiver_id: "thief.near", amount: "1" })), gas: 10_000_000_000_000n },
    );
    expect(await (await post(signDelegate(delegate))).json()).toEqual({ error: "call_not_allowed" });
  });

  test("no longer sends tokens into the claims module", async () => {
    const delegate = delegateFor(
      { receiverId: "usdc.near" },
      { methodName: "ft_transfer_call", args: utf8(JSON.stringify({ receiver_id: "treasury.ije.near", amount: "1", msg: "" })) },
    );
    expect(await (await post(signDelegate(delegate))).json()).toEqual({ error: "call_not_allowed" });
  });

  test("refuses inherited object keys as method names", async () => {
    const response = await post(signDelegate(delegateFor({}, { methodName: "toString", deposit: 0n })));
    expect(await response.json()).toEqual({ error: "call_not_allowed" });
  });

  test("refuses too much gas", async () => {
    const response = await post(signDelegate(delegateFor({}, { gas: 200_000_000_000_000n })));
    expect(await response.json()).toEqual({ error: "gas_not_allowed" });
  });

  test("refuses a delegate signed by another key", async () => {
    const response = await post(signDelegate(delegateFor(), ed25519.utils.randomSecretKey()));
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "invalid_delegate_signature" });
  });

  test("refuses a nonce the account already used", async () => {
    const response = await post(signDelegate(delegateFor({ nonce: 1n })));
    expect(response.status).toBe(409);
  });

  test("refuses an expiry too far ahead", async () => {
    const response = await post(signDelegate(delegateFor({ maxBlockHeight: 5_000n })));
    expect(await response.json()).toEqual({ error: "max_block_height_out_of_range" });
  });

  test("limits each account to 30 relays an hour", async () => {
    for (let i = 0; i < 30; i++) {
      await env.DB.prepare("INSERT INTO relay_log (sender_id, key_id, created_at) VALUES ('runner.ije.near', 'other', ?)")
        .bind(nowSeconds())
        .run();
    }
    const response = await post(signDelegate(delegateFor()));
    expect(response.status).toBe(429);
    expect(sent).toHaveLength(0);
  });

  test("retries with a fresh nonce when NEAR rejects one", async () => {
    nonceFailures = 1;
    expect((await post(signDelegate(delegateFor()))).status).toBe(200);
    expect(sent).toHaveLength(1);
  });

  test("refuses unknown devices", async () => {
    await env.DB.prepare("DELETE FROM devices").run();
    const response = await post(signDelegate(delegateFor()));
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unknown_device" });
  });

  test("answers misconfigured until the relayer key is set", async () => {
    env = { ...env, RELAYER_SECRET_KEY: "" };
    const response = await post(signDelegate(delegateFor()));
    expect(response.status).toBe(503);
  });
});

describe("byte compatibility with near-api-js", () => {
  test("delegate actions encode exactly as the official library does", async () => {
    const near = await import("@near-js/transactions");
    const { PublicKey } = await import("@near-js/crypto");
    const delegate = delegateFor();
    const call = delegate.actions[0];
    const reference = near.buildDelegateAction({
      senderId: delegate.senderId,
      receiverId: delegate.receiverId,
      actions: [near.actionCreators.functionCall(call.methodName, call.args, call.gas, call.deposit)],
      nonce: delegate.nonce,
      maxBlockHeight: delegate.maxBlockHeight,
      publicKey: PublicKey.from(userKeyText),
    });
    expect(Buffer.from(delegateDigest(encodeDelegateAction(delegate))).equals(Buffer.from(hash(near.encodeDelegateAction(reference))))).toBe(true);
    const signature = ed25519.sign(delegateDigest(encodeDelegateAction(delegate)), userSecret);
    const referenceSigned = near.encodeSignedDelegate(
      new near.SignedDelegate({ delegateAction: reference, signature: new near.Signature({ keyType: 0, data: signature }) }),
    );
    expect(Buffer.from(encodeSignedDelegate(delegate, signature)).equals(Buffer.from(referenceSigned))).toBe(true);
  });

  test("the relayed transaction decodes with the official library", async () => {
    const near = await import("@near-js/transactions");
    const { buildRelayTransaction, parseRelayerKey } = await import("../src/nearTx");
    const key = parseRelayerKey(`ed25519:${base58.encode(new Uint8Array([...relayerSecret, ...relayerPublic]))}`);
    const signedDelegate = Buffer.from(signDelegate(delegateFor()), "base64");
    const built = buildRelayTransaction({ relayerId: "relayer.ije.near", key, nonce: 6n, blockHash: new Uint8Array(32), signedDelegate });
    const decoded = near.decodeSignedTransaction(built.signedTransaction);
    expect(decoded.transaction.signerId).toBe("relayer.ije.near");
    expect(decoded.transaction.receiverId).toBe("runner.ije.near");
    expect(BigInt(decoded.transaction.nonce)).toBe(6n);
    const inner = decoded.transaction.actions[0].signedDelegate;
    expect(inner?.delegateAction.senderId).toBe("runner.ije.near");
    expect(inner?.delegateAction.actions[0].functionCall?.methodName).toBe("give_up");
  });
});
