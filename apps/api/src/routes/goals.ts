import { base58 } from "@scure/base";
import { fromBase64, toBase64, toHex, utf8 } from "../codec";
import { nowSeconds, requireSettings, type Env } from "../env";
import { HttpError, json, parseObject, readJson, stringField, type Json } from "../http";
import { isAccountId, parsePublicKey, rpcCall, verifyNep413, viewAccessKey } from "../near";
import { buildFunctionTransaction, parseRelayerKey } from "../nearTx";
import { oneClick, oneClickJson } from "../oneClick";
import { outcome } from "./relay";
import { checkDevice, consumeChallenge } from "./runner";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DIGITS = /^[1-9]\d{0,30}$/;
/** A claimed quote with no response after this long is abandoned. */
const STALE_CLAIM_S = 30;
const SHARE_WAIT_MS = 20_000;
const PAYOUT_TTL_MS = 30 * 60 * 1000;

interface GoalRow {
  id: string;
  account_id: string;
  origin_asset: string;
  return_address: string;
  distance_m: number;
  max_seconds: number | null;
  request: string;
  quote: string | null;
  lock_id: string | null;
  locked_amount: string | null;
  locked_at: number | null;
  created_at: number;
  receiver_id: string | null;
  amount: string | null;
  deadline: string | null;
  withdrawn: number | null;
}

interface LockView {
  id: string;
  owner_id: string;
  amount: string;
  goal: { distance_m: number; max_seconds: number | null };
  created_at: string;
}

const SELECT = `SELECT g.*, p.receiver_id, p.amount, p.deadline, p.withdrawn
  FROM goals g LEFT JOIN goal_payouts p ON p.goal_id = g.id`;

// MARK: - Payable goal quote (via /v1/intents/v0/quote)

/**
 * A payable 1Click quote that delivers to the escrow. Checks it funds the
 * deployed `DepositMsg { owner, goal, funding_id }`, then keeps one saved
 * quote per goal: concurrent requests share it, an identical retry gets it
 * back, a different request for the same goal is refused.
 */
export async function goalQuote(env: Env, quote: Json, body: string): Promise<Response> {
  if (quote.swapType !== "EXACT_OUTPUT" || quote.depositType !== "ORIGIN_CHAIN" ||
      quote.refundType !== "ORIGIN_CHAIN" || quote.recipientType !== "DESTINATION_CHAIN" ||
      quote.destinationAsset !== `nep141:${env.TOKEN_CONTRACT}`) {
    throw new HttpError(422, "invalid_goal_quote");
  }
  const originAsset = stringField(quote, "originAsset", 256);
  const refundTo = stringField(quote, "refundTo", 128);
  const amount = stringField(quote, "amount", 32);
  if (!DIGITS.test(amount)) throw new HttpError(422, "invalid_goal_quote");
  const msg = parseObject(stringField(quote, "customRecipientMsg", 512), "invalid_goal_quote");
  const goal = msg.goal as Json | undefined;
  const id = msg.funding_id;
  const maxSeconds = goal?.max_seconds ?? null;
  if (typeof msg.owner !== "string" || !isAccountId(msg.owner) || typeof id !== "string" || !UUID.test(id) ||
      !Number.isInteger(goal?.distance_m) || (goal!.distance_m as number) < 1_000 || (goal!.distance_m as number) > 100_000 ||
      (maxSeconds !== null && (!Number.isInteger(maxSeconds) || (maxSeconds as number) < 60 || (maxSeconds as number) > 86_400))) {
    throw new HttpError(422, "invalid_goal_quote");
  }
  // What makes a retry identical; the deadline is allowed to move.
  const request = JSON.stringify([originAsset, amount, refundTo, msg.owner, goal!.distance_m, maxSeconds]);

  const waitUntil = Date.now() + SHARE_WAIT_MS;
  while (true) {
    const saved = await env.DB.prepare("SELECT request, quote, created_at FROM goals WHERE id = ?")
      .bind(id).first<{ request: string; quote: string | null; created_at: number }>();
    if (saved) {
      if (saved.request !== request) throw new HttpError(409, "goal_quote_conflict");
      if (saved.quote) return quoteResponse(saved.quote, 200);
      if (saved.created_at < nowSeconds() - STALE_CLAIM_S) {
        await env.DB.prepare("DELETE FROM goals WHERE id = ? AND quote IS NULL AND created_at = ?")
          .bind(id, saved.created_at).run();
      } else if (Date.now() > waitUntil) {
        throw new HttpError(503, "goal_quote_pending");
      } else {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      continue;
    }
    const claim = await env.DB.prepare(`INSERT OR IGNORE INTO goals
      (id, account_id, origin_asset, return_address, distance_m, max_seconds, request, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(id, msg.owner, originAsset, refundTo, goal!.distance_m as number, maxSeconds, request, nowSeconds()).run();
    if (claim.meta.changes === 1) break;
  }

  try {
    const upstream = await oneClick(env.ONE_CLICK_API_KEY, "/v0/quote", {
      method: "POST", body, headers: { "content-type": "application/json" },
    });
    const text = await upstream.text();
    if (upstream.ok) {
      await env.DB.prepare("UPDATE goals SET quote = ? WHERE id = ?").bind(text, id).run();
    } else {
      console.error(`goal quote rejected by 1Click: ${upstream.status} ${text.slice(0, 500)}`);
      await env.DB.prepare("DELETE FROM goals WHERE id = ? AND quote IS NULL").bind(id).run();
    }
    return quoteResponse(text, upstream.status);
  } catch (error) {
    await env.DB.prepare("DELETE FROM goals WHERE id = ? AND quote IS NULL").bind(id).run();
    throw error;
  }
}

function quoteResponse(body: string, status: number): Response {
  return new Response(body, { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });
}

// MARK: - List

/** Locked goals and their withdrawal state. A funded goal appears once its lock is on chain. */
export async function listGoals(request: Request, env: Env): Promise<Response> {
  const { account } = await authenticate(request, env, "list");
  const query = env.DB.prepare(`${SELECT} WHERE g.account_id = ? AND g.quote IS NOT NULL
    ORDER BY g.created_at`).bind(account);
  let rows = (await query.all<GoalRow>()).results;
  const locks = rows.some((row) => !row.withdrawn)
    ? await view<LockView[]>(env, env.ESCROW_CONTRACT, "get_locks", { account_id: account }) : [];
  if (await attachLocks(env, rows, locks)) rows = (await query.all<GoalRow>()).results;
  const open = new Set(locks.map((lock) => lock.id));
  const balance = rows.some((row) => row.receiver_id && !row.withdrawn)
    ? BigInt(await view<string>(env, env.ESCROW_CONTRACT, "get_balance", { account_id: account })) : 0n;
  const goals = (await Promise.all(rows.filter((row) => row.lock_id && !row.withdrawn).reverse().map(async (row) => ({
    id: row.id,
    state: await goalState(env, row, open, balance),
    distance_m: row.distance_m,
    max_seconds: row.max_seconds,
    amount: row.locked_amount,
    origin_asset: row.origin_asset,
    return_address: row.return_address,
    lock_id: row.lock_id,
    locked_at: row.locked_at,
  })))).filter((goal) => goal.state !== "withdrawn");
  // A withdrawn goal is finished: it leaves the list, with no history.
  return json({ goals });
}

/**
 * Link each paid goal to the first unclaimed lock with its goal and amount,
 * created after its quote. "Paid" is 1Click SUCCESS for the goal's deposit
 * address, so an abandoned quote with the same goal never takes the lock.
 */
async function attachLocks(env: Env, rows: GoalRow[], locks: LockView[]): Promise<boolean> {
  const claimed = new Set(rows.map((row) => row.lock_id).filter(Boolean));
  let changed = false;
  for (const row of rows.filter((row) => !row.lock_id)) {
    const amount = (JSON.parse(row.request) as unknown[])[1];
    const lock = locks
      .filter((lock) => !claimed.has(lock.id) && lock.amount === amount &&
        lock.goal.distance_m === row.distance_m && (lock.goal.max_seconds ?? null) === row.max_seconds &&
        BigInt(lock.created_at) / 1_000_000_000n >= BigInt(row.created_at))
      .sort((a, b) => Number(BigInt(a.id) - BigInt(b.id)))[0];
    if (!lock || !await depositSucceeded(env, row.quote!)) continue;
    claimed.add(lock.id);
    const lockedAt = Number((BigInt(lock.created_at) + 999_999_999n) / 1_000_000_000n);
    const update = await env.DB.prepare(`UPDATE goals SET lock_id = ?, locked_amount = ?, locked_at = ?
      WHERE id = ? AND lock_id IS NULL`).bind(lock.id, lock.amount, lockedAt, row.id).run();
    changed ||= update.meta.changes === 1;
  }
  return changed;
}

/** Whether 1Click delivered the deposit made to this saved quote's address. */
async function depositSucceeded(env: Env, savedQuote: string): Promise<boolean> {
  const { quote } = JSON.parse(savedQuote) as { quote?: { depositAddress?: string; depositMemo?: string } };
  if (!quote?.depositAddress) return false;
  const query = new URLSearchParams({ depositAddress: quote.depositAddress });
  if (quote.depositMemo) query.set("depositMemo", quote.depositMemo);
  const report = await oneClickJson<{ status?: string }>(env.ONE_CLICK_API_KEY, `/v0/status?${query}`)
    .catch(() => undefined);
  return report?.status === "SUCCESS";
}

/**
 * The chain decides whether the payout has left: while the escrow still
 * holds the amount the goal can be withdrawn (or the withdrawal resumed);
 * once it has left, 1Click is delivering until it reports SUCCESS.
 */
async function goalState(env: Env, row: GoalRow, open: Set<string>, balance: bigint): Promise<string> {
  if (row.withdrawn) return "withdrawn";
  if (open.has(row.lock_id!)) return "locked";
  if (!row.receiver_id) return "ready_to_withdraw";
  const report = await oneClickJson<{ status?: string }>(env.ONE_CLICK_API_KEY,
    `/v0/status?depositAddress=${encodeURIComponent(row.receiver_id)}`).catch(() => undefined);
  if (report?.status === "SUCCESS") {
    await env.DB.prepare("UPDATE goal_payouts SET withdrawn = 1 WHERE goal_id = ?").bind(row.id).run();
    return "withdrawn";
  }
  return balance >= BigInt(row.amount!) ? "ready_to_withdraw" : "withdrawing";
}

// MARK: - Withdraw

/**
 * Reserve the payout for an unlocked goal: the amount that landed in the
 * escrow, sent through a 1Click deposit account back to the saved return
 * address on the original chain. The runner signs `withdraw` on the escrow
 * and submits it through `/v1/relay`.
 */
export async function withdrawGoal(request: Request, env: Env): Promise<Response> {
  const { account, payload } = await authenticate(request, env, "withdraw");
  const id = stringField(payload, "goal_id", 36);
  const row = await env.DB.prepare(`${SELECT} WHERE g.id = ? AND g.account_id = ? AND g.lock_id IS NOT NULL`)
    .bind(id, account).first<GoalRow>();
  if (!row) throw new HttpError(404, "goal_not_found");
  if (row.withdrawn) throw new HttpError(409, "goal_withdrawn");
  if (row.receiver_id && Date.parse(row.deadline!) > Date.now() + 60_000) {
    return json({ receiver_id: row.receiver_id, amount: row.amount });
  }
  const locks = await view<LockView[]>(env, env.ESCROW_CONTRACT, "get_locks", { account_id: account });
  if (locks.some((lock) => lock.id === row.lock_id)) throw new HttpError(409, "goal_locked");
  const amount = row.locked_amount!;
  const balance = await view<string>(env, env.ESCROW_CONTRACT, "get_balance", { account_id: account });
  if (BigInt(balance) < BigInt(amount)) throw new HttpError(409, "escrow_balance_unavailable");

  const { quote } = await oneClickJson<{ quote: { depositAddress?: string; amountIn?: string; deadline?: string } }>(
    env.ONE_CLICK_API_KEY, "/v0/quote", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({
        dry: false, swapType: "EXACT_INPUT", slippageTolerance: 100,
        originAsset: `nep141:${env.TOKEN_CONTRACT}`, depositType: "ORIGIN_CHAIN", amount,
        destinationAsset: row.origin_asset, recipient: row.return_address, recipientType: "DESTINATION_CHAIN",
        refundTo: account, refundType: "ORIGIN_CHAIN",
        deadline: new Date(Date.now() + PAYOUT_TTL_MS).toISOString(),
      }),
    });
  if (!quote.depositAddress || !isAccountId(quote.depositAddress) || quote.amountIn !== amount || !quote.deadline) {
    throw new HttpError(502, "invalid_withdrawal_quote");
  }
  await registerStorage(env, quote.depositAddress);

  // First reservation wins; an expired one is replaced only if nobody else replaced it first.
  await (row.receiver_id
    ? env.DB.prepare(`UPDATE goal_payouts SET receiver_id = ?, amount = ?, deadline = ?
        WHERE goal_id = ? AND deadline = ? AND withdrawn = 0`)
      .bind(quote.depositAddress, amount, quote.deadline, id, row.deadline)
    : env.DB.prepare("INSERT OR IGNORE INTO goal_payouts (goal_id, receiver_id, amount, deadline) VALUES (?, ?, ?, ?)")
      .bind(id, quote.depositAddress, amount, quote.deadline)).run();
  const payout = await env.DB.prepare("SELECT receiver_id, amount FROM goal_payouts WHERE goal_id = ?")
    .bind(id).first<{ receiver_id: string; amount: string }>();
  return json(payout);
}

/** The escrow's `ft_transfer` fails on an unregistered receiver: pay its USDC storage once. */
async function registerStorage(env: Env, receiver: string): Promise<void> {
  if (await view(env, env.TOKEN_CONTRACT, "storage_balance_of", { account_id: receiver })) return;
  const bounds = await view<{ min?: string }>(env, env.TOKEN_CONTRACT, "storage_balance_bounds", {});
  if (!bounds.min || !/^\d{1,22}$/.test(bounds.min)) throw new HttpError(503, "usdc_storage_cost_unexpected");
  requireSettings(env, ["RELAYER_ACCOUNT_ID", "RELAYER_SECRET_KEY"]);
  const key = parseRelayerKey(env.RELAYER_SECRET_KEY);
  const access = await viewAccessKey(env.NEAR_RPC_URL, env.RELAYER_ACCOUNT_ID, key.publicKeyText);
  if (!access?.fullAccess) throw new HttpError(503, "relayer_key_missing");
  const transaction = buildFunctionTransaction({
    signerId: env.RELAYER_ACCOUNT_ID, key, nonce: access.nonce + 1n,
    blockHash: base58.decode(access.blockHash), receiverId: env.TOKEN_CONTRACT,
    call: {
      methodName: "storage_deposit",
      args: utf8(JSON.stringify({ account_id: receiver, registration_only: true })),
      gas: 30_000_000_000_000n, deposit: BigInt(bounds.min),
    },
  });
  const { result } = await rpcCall(env.NEAR_RPC_URL, "send_tx", { signed_tx_base64: toBase64(transaction), wait_until: "FINAL" });
  if (!result || outcome(result).status !== "succeeded") throw new HttpError(503, "withdrawal_storage_pending");
}

// MARK: - Shared

async function view<T>(env: Env, contract: string, method: string, args: Json): Promise<T> {
  const { result, error } = await rpcCall(env.NEAR_RPC_URL, "query", {
    request_type: "call_function", finality: "final", account_id: contract,
    method_name: method, args_base64: toBase64(utf8(JSON.stringify(args))),
  });
  if (!Array.isArray(result?.result)) {
    console.error(`view ${contract}.${method} failed: ${JSON.stringify(error ?? result ?? null).slice(0, 300)}`);
    throw new HttpError(502, "chain_view_unavailable");
  }
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(result.result as number[]))) as T;
}

/** NEP-413 signed by the runner's implicit account, asserted by the device's App Attest key. */
async function authenticate(request: Request, env: Env, action: string): Promise<{ account: string; payload: Json }> {
  requireSettings(env, ["APP_ID", "NEAR_RECIPIENT"]);
  const body = await readJson(request);
  const signed = stringField(body, "payload", 4096);
  const payload = parseObject(signed, "invalid_payload");
  if (payload.action !== action) throw new HttpError(401, "invalid_action");
  const account = stringField(payload, "account_id", 64);
  const publicKey = parsePublicKey(stringField(body, "near_public_key", 128));
  const nonce = await consumeChallenge(env, stringField(payload, "challenge", 64));
  if (account !== toHex(publicKey) || !verifyNep413({
    message: signed, nonce, recipient: env.NEAR_RECIPIENT, publicKey,
    signature: stringField(body, "near_signature", 128),
  })) throw new HttpError(401, "invalid_near_signature");
  await checkDevice(env, stringField(body, "key_id", 64),
    fromBase64(stringField(body, "assertion", 4096), "invalid_assertion"), signed);
  return { account, payload };
}
