import { afterEach, expect, test } from "bun:test";
import { ed25519 } from "@noble/curves/ed25519.js";
import { p256 } from "@noble/curves/nist.js";
import { base58 } from "@scure/base";
import { fromBase64, hashHex, toBase64, toHex, utf8 } from "../src/codec";
import type { Env } from "../src/env";
import { handle } from "../src/index";
import { nep413Digest } from "../src/near";
import { createEnv, makeAssertion, stubFetch } from "./support";

const BASE_USDC = "nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near";
const RETURN = "0x1111111111111111111111111111111111111111";
const PAYOUT = "a".repeat(64);

let restore: (() => void) | undefined;
afterEach(() => restore?.());

async function runner(env: Env) {
  const keyId = toBase64(crypto.getRandomValues(new Uint8Array(32)));
  const device = p256.utils.randomSecretKey();
  const secret = ed25519.utils.randomSecretKey();
  const publicKey = ed25519.getPublicKey(secret);
  let counter = 0;
  await env.DB.prepare("INSERT INTO devices (key_id, public_key, counter, created_at) VALUES (?, ?, 0, 0)")
    .bind(keyId, toBase64(p256.getPublicKey(device, false))).run();
  return {
    account: toHex(publicKey),
    proxy(body: object, path = "/v0/quote") {
      const text = JSON.stringify(body);
      const clientData = `POST /v1/intents${path} ${hashHex(utf8(text))}`;
      return handle(new Request(`https://runner.test/v1/intents${path}`, {
        method: "POST", body: text, headers: {
          "x-runner-key-id": keyId,
          "x-runner-assertion": toBase64(makeAssertion(device, utf8(clientData), ++counter)),
        },
      }), env);
    },
    async call(action: string, fields: object = {}) {
      const challengeResponse = await handle(new Request("https://runner.test/v1/challenge", { method: "POST" }), env);
      const { challenge } = await challengeResponse.json() as { challenge: string };
      const payload = JSON.stringify({ account_id: toHex(publicKey), challenge, action, ...fields });
      const digest = nep413Digest(payload, fromBase64(challenge, "test"), env.NEAR_RECIPIENT);
      return handle(new Request(`https://runner.test/v1/goals/${action}`, {
        method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({
          payload, key_id: keyId,
          assertion: toBase64(makeAssertion(device, utf8(payload), ++counter)),
          near_public_key: `ed25519:${base58.encode(publicKey)}`,
          near_signature: toBase64(ed25519.sign(digest, secret)),
        }),
      }), env);
    },
  };
}

function goalQuote(env: Env, owner: string, goalID: string, overrides: object = {}) {
  return {
    dry: false, swapType: "EXACT_OUTPUT", slippageTolerance: 100, originAsset: BASE_USDC,
    depositType: "ORIGIN_CHAIN", destinationAsset: `nep141:${env.TOKEN_CONTRACT}`, amount: "5000000",
    refundTo: RETURN, refundType: "ORIGIN_CHAIN", recipient: env.ESCROW_CONTRACT,
    recipientType: "DESTINATION_CHAIN", deadline: new Date(Date.now() + 600_000).toISOString(),
    customRecipientMsg: JSON.stringify({ owner, goal: { distance_m: 5000, max_seconds: 1800 }, funding_id: goalID }),
    ...overrides,
  };
}

/** Chain + 1Click stub. `locks` and `payoutStatus` are mutable per test. */
type ChainState = { locks: object[]; balance?: string; payoutStatus?: string; paid?: Set<string> };

function chain(env: Env, state: ChainState) {
  const calls = { quotes: 0, withdrawalQuotes: [] as Record<string, unknown>[] };
  restore = stubFetch(async (url, init) => {
    if (url === env.NEAR_RPC_URL) {
      const { params } = JSON.parse(String(init.body));
      const value = params.method_name === "get_locks" ? state.locks
        : params.method_name === "get_balance" ? (state.balance ?? "0")
        : params.method_name === "storage_balance_of" ? { total: "1" } : null;
      return Response.json({ jsonrpc: "2.0", id: 1, result: { result: [...utf8(JSON.stringify(value))] } });
    }
    if (url.endsWith("/v0/quote")) {
      const body = JSON.parse(String(init.body));
      if (body.recipient === env.ESCROW_CONTRACT) {
        calls.quotes++;
        await new Promise((resolve) => setTimeout(resolve, 20));
        const depositAddress = `0xdeposit${calls.quotes}`;
        return Response.json({ quote: { depositAddress, amountIn: "5010000", amountOut: body.amount } }, { status: 201 });
      }
      calls.withdrawalQuotes.push(body);
      return Response.json({ quote: { depositAddress: PAYOUT, amountIn: body.amount, amountOut: "4990000",
        deadline: new Date(Date.now() + 1_800_000).toISOString() } });
    }
    if (url.includes("/v0/status")) {
      const address = new URL(url).searchParams.get("depositAddress")!;
      if (address === PAYOUT) return Response.json({ status: state.payoutStatus ?? "PENDING_DEPOSIT" });
      return Response.json({ status: state.paid?.has(address) ? "SUCCESS" : "PENDING_DEPOSIT" });
    }
    if (url.endsWith("/v0/tokens")) return Response.json([{ assetId: BASE_USDC }]);
    throw new Error(`unexpected fetch ${url}`);
  });
  return calls;
}

const lock = (owner: string, id: string, amount = "5000000") => ({
  id, owner_id: owner, amount, goal: { distance_m: 5000, max_seconds: 1800 },
  created_at: String(BigInt(Date.now() + 1000) * 1_000_000n),
});

test("concurrent requests for one goal share one upstream quote; an identical retry returns it", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  const calls = chain(env, { locks: [] });
  const id = crypto.randomUUID();
  const responses = await Promise.all([1, 2, 3].map(() => owner.proxy(goalQuote(env, owner.account, id))));
  const bodies = await Promise.all(responses.map((response) => response.text()));
  expect(calls.quotes).toBe(1);
  expect(new Set(bodies).size).toBe(1);
  expect(JSON.parse(bodies[0]).quote.depositAddress).toBe("0xdeposit1");

  const retry = await owner.proxy(goalQuote(env, owner.account, id, { deadline: new Date().toISOString() }));
  expect(retry.status).toBe(200);
  expect(await retry.text()).toBe(bodies[0]);
  expect(calls.quotes).toBe(1);

  const changed = await owner.proxy(goalQuote(env, owner.account, id, { refundTo: "0x2222222222222222222222222222222222222222" }));
  expect(changed.status).toBe(409);
});

test("a payable escrow quote must fund the deployed DepositMsg", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  const calls = chain(env, { locks: [] });
  const id = crypto.randomUUID();
  const bad = [
    { swapType: "EXACT_INPUT" },
    { destinationAsset: "nep141:other.near" },
    { customRecipientMsg: JSON.stringify({ owner: owner.account, goal: { distance_m: 500 }, funding_id: id }) },
    { customRecipientMsg: JSON.stringify({ owner: owner.account, goal: { distance_m: 5000 }, funding_id: "x" }) },
    { customRecipientMsg: undefined },
  ];
  for (const overrides of bad) {
    expect([400, 422]).toContain((await owner.proxy(goalQuote(env, owner.account, id, overrides))).status);
  }
  expect(calls.quotes).toBe(0);
});

test("the proxy forwards other routes unchanged and refuses unknown ones", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  chain(env, { locks: [] });
  const dry = await owner.proxy({ dry: true, recipient: "someone.near" });
  expect(dry.status).toBe(200);
  expect((await owner.proxy({}, "/v0/deposit/submit")).status).toBe(404);
  const unsigned = await handle(new Request("https://runner.test/v1/intents/v0/quote", { method: "POST", body: "{}" }), env);
  expect(unsigned.status).toBe(401);
});

test("a goal shows once locked, withdraws the landed amount once, and reads withdrawn after delivery", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  const state: ChainState = { locks: [], paid: new Set(["0xdeposit1"]) };
  const calls = chain(env, state);
  const id = crypto.randomUUID();
  await (await owner.proxy(goalQuote(env, owner.account, id, { amount: "4990000" }))).text();

  const list = async () => (await (await owner.call("list")).json() as { goals: Record<string, unknown>[] }).goals;
  expect(await list()).toEqual([]);

  state.locks = [lock(owner.account, "7", "4990000")];
  expect(await list()).toMatchObject([{ id, state: "locked", lock_id: "7", amount: "4990000", return_address: RETURN }]);
  expect((await owner.call("withdraw", { goal_id: id })).status).toBe(409);

  state.locks = [];
  state.balance = "4990000";
  expect(await list()).toMatchObject([{ id, state: "ready_to_withdraw" }]);
  const payouts = await Promise.all([1, 2].map(async () => (await owner.call("withdraw", { goal_id: id })).json()));
  expect(payouts[0]).toEqual({ receiver_id: PAYOUT, amount: "4990000" });
  expect(payouts[1]).toEqual(payouts[0]);
  expect(calls.withdrawalQuotes[0]).toMatchObject({
    swapType: "EXACT_INPUT", amount: "4990000", destinationAsset: BASE_USDC, recipient: RETURN,
  });
  const again = await (await owner.call("withdraw", { goal_id: id })).json();
  expect(again).toEqual(payouts[0]);

  // Reserved but still in the escrow: withdrawable (resume).
  expect(await list()).toMatchObject([{ state: "ready_to_withdraw" }]);
  // Left the escrow; 1Click hasn't seen it yet: delivering, not withdrawable.
  state.balance = "0";
  expect(await list()).toMatchObject([{ state: "withdrawing" }]);
  state.payoutStatus = "PROCESSING";
  expect(await list()).toMatchObject([{ state: "withdrawing" }]);
  state.payoutStatus = "SUCCESS";
  expect(await list()).toEqual([]);
  expect((await owner.call("withdraw", { goal_id: id })).status).toBe(409);
});

test("another runner's goal is not visible or withdrawable", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  const other = await runner(env);
  const state: ChainState = { locks: [], paid: new Set(["0xdeposit1"]) };
  chain(env, state);
  const id = crypto.randomUUID();
  await (await owner.proxy(goalQuote(env, owner.account, id))).text();
  state.locks = [lock(owner.account, "9")];
  expect((await (await other.call("list")).json() as { goals: unknown[] }).goals).toEqual([]);
  expect((await other.call("withdraw", { goal_id: id })).status).toBe(404);
});

test("an abandoned quote with the same goal never takes the lock of the paid one", async () => {
  const env = createEnv({ ONE_CLICK_API_KEY: "key" });
  const owner = await runner(env);
  const state: ChainState = { locks: [], paid: new Set(["0xdeposit2"]) };
  chain(env, state);
  const abandoned = crypto.randomUUID();
  const paid = crypto.randomUUID();
  await (await owner.proxy(goalQuote(env, owner.account, abandoned))).text();
  await (await owner.proxy(goalQuote(env, owner.account, paid,
    { refundTo: "0x2222222222222222222222222222222222222222" }))).text();
  state.locks = [lock(owner.account, "11"), lock(owner.account, "12", "6000000")];

  const { goals } = await (await owner.call("list")).json() as { goals: Record<string, unknown>[] };
  expect(goals).toMatchObject([
    { id: paid, lock_id: "11", amount: "5000000", return_address: "0x2222222222222222222222222222222222222222" },
  ]);
});
