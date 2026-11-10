import { base58 } from "@scure/base";
import { fromBase64, toBase64 } from "../codec";
import { nowSeconds, requireSettings, type Env } from "../env";
import { HttpError, json, readJson, stringField } from "../http";
import { isAccountId, rpcCall, viewAccessKey } from "../near";
import {
  buildRelayTransaction,
  decodeSignedDelegate,
  parseRelayerKey,
  verifyDelegateSignature,
  type DelegateAction,
} from "../nearTx";
import { checkDevice } from "./runner";

const ONE_YOCTO = 1n;
const TGAS = 1_000_000_000_000n;
const MAX_BLOCK_LEAD = 1_000n;
const RELAYS_PER_HOUR = 30;
const NONCE_RETRIES = 3;

interface Rule {
  deposit: bigint;
  maxGas: bigint;
  receivers?: string[];
}

type Policy = Record<string, Record<string, Rule>>;

function policy(env: Env): Policy {
  const call = (deposit: bigint, tgas: bigint, receivers?: string[]): Rule => ({ deposit, maxGas: tgas * TGAS, receivers });
  return {
    [env.TREASURY_CONTRACT]: { claim: call(0n, 200n) },
    [env.ESCROW_CONTRACT]: {
      unlock: call(0n, 100n),
      flush_pool: call(0n, 100n),
      give_up: call(ONE_YOCTO, 100n),
      withdraw: call(ONE_YOCTO, 100n),
      lock_from_balance: call(ONE_YOCTO, 100n),
    },
    [env.TOKEN_CONTRACT]: {
      ft_transfer_call: call(ONE_YOCTO, 100n, [env.ESCROW_CONTRACT]),
      ft_transfer: call(ONE_YOCTO, 30n, [env.DAO_ACCOUNT]),
    },
  };
}

function checkPolicy(env: Env, delegate: DelegateAction): void {
  const call = delegate.actions[0];
  const allowed = policy(env)[delegate.receiverId];
  const rule = allowed && Object.hasOwn(allowed, call.methodName) ? allowed[call.methodName] : undefined;
  if (!rule) {
    throw new HttpError(422, "call_not_allowed");
  }
  if (call.deposit !== rule.deposit) {
    throw new HttpError(422, "deposit_not_allowed");
  }
  if (call.gas <= 0n || call.gas > rule.maxGas) {
    throw new HttpError(422, "gas_not_allowed");
  }
  if (rule.receivers) {
    let receiver: unknown;
    try {
      receiver = (JSON.parse(new TextDecoder().decode(call.args)) as { receiver_id?: unknown }).receiver_id;
    } catch {
      throw new HttpError(422, "call_not_allowed");
    }
    if (typeof receiver !== "string" || !rule.receivers.includes(receiver)) {
      throw new HttpError(422, "call_not_allowed");
    }
  }
}

async function recordRelay(env: Env, senderId: string, keyId: string): Promise<void> {
  const now = nowSeconds();
  const result = await env.DB.prepare(
    `INSERT INTO relay_log (sender_id, key_id, created_at)
     SELECT ?1, ?2, ?3
     WHERE (SELECT COUNT(*) FROM relay_log WHERE sender_id = ?1 AND created_at > ?4) < ?5
       AND (SELECT COUNT(*) FROM relay_log WHERE key_id = ?2 AND created_at > ?4) < ?5`,
  )
    .bind(senderId, keyId, now, now - 3600, RELAYS_PER_HOUR)
    .run();
  if (result.meta.changes !== 1) {
    throw new HttpError(429, "too_many_relays");
  }
}

function outcome(result: Record<string, unknown>): { status: "succeeded" | "failed"; failure?: unknown } {
  const status = result.status as Record<string, unknown> | undefined;
  const receipts = (result.receipts_outcome as { outcome?: { status?: Record<string, unknown> } }[] | undefined) ?? [];
  const failure =
    (status && "Failure" in status ? status.Failure : undefined) ??
    receipts.map((receipt) => receipt.outcome?.status?.Failure).find((value) => value !== undefined);
  return failure === undefined ? { status: "succeeded" } : { status: "failed", failure };
}

export async function relay(request: Request, env: Env): Promise<Response> {
  requireSettings(env, [
    "APP_ID",
    "NEAR_RPC_URL",
    "TREASURY_CONTRACT",
    "ESCROW_CONTRACT",
    "TOKEN_CONTRACT",
    "DAO_ACCOUNT",
    "RELAYER_ACCOUNT_ID",
    "RELAYER_SECRET_KEY",
  ]);
  const body = await readJson(request);
  const signedDelegateText = stringField(body, "signed_delegate", 32768);
  const keyId = stringField(body, "key_id", 64);
  const assertion = fromBase64(stringField(body, "assertion", 4096), "invalid_assertion");
  const signedDelegate = fromBase64(signedDelegateText, "invalid_signed_delegate");

  const signed = decodeSignedDelegate(signedDelegate);
  const delegate = signed.delegate;
  if (!isAccountId(delegate.senderId)) {
    throw new HttpError(400, "invalid_sender_id");
  }
  checkPolicy(env, delegate);
  if (!verifyDelegateSignature(signed)) {
    throw new HttpError(401, "invalid_delegate_signature");
  }

  await checkDevice(env, keyId, assertion, signedDelegateText);

  const senderKey = await viewAccessKey(env.NEAR_RPC_URL, delegate.senderId, `ed25519:${base58.encode(delegate.publicKey)}`);
  if (!senderKey?.fullAccess) {
    throw new HttpError(401, "sender_key_not_full_access");
  }
  if (delegate.nonce <= senderKey.nonce) {
    throw new HttpError(409, "delegate_nonce_used");
  }
  if (delegate.maxBlockHeight <= senderKey.blockHeight || delegate.maxBlockHeight > senderKey.blockHeight + MAX_BLOCK_LEAD) {
    throw new HttpError(422, "max_block_height_out_of_range");
  }

  await recordRelay(env, delegate.senderId, keyId);

  const key = parseRelayerKey(env.RELAYER_SECRET_KEY);
  for (let attempt = 0; attempt < NONCE_RETRIES; attempt++) {
    const relayerKey = await viewAccessKey(env.NEAR_RPC_URL, env.RELAYER_ACCOUNT_ID, key.publicKeyText);
    if (!relayerKey) {
      throw new HttpError(503, "relayer_key_missing");
    }
    const transaction = buildRelayTransaction({
      relayerId: env.RELAYER_ACCOUNT_ID,
      key,
      nonce: relayerKey.nonce + 1n,
      blockHash: base58.decode(relayerKey.blockHash),
      signedDelegate,
    });
    const response = await rpcCall(env.NEAR_RPC_URL, "send_tx", {
      signed_tx_base64: toBase64(transaction.signedTransaction),
      wait_until: "EXECUTED_OPTIMISTIC",
    });
    if (response.result) {
      return json({ transaction_hash: transaction.hash, ...outcome(response.result) });
    }
    const cause = JSON.stringify(response.error ?? {});
    if (!cause.includes("InvalidNonce")) {
      console.error(`relay rejected: ${cause}`);
      throw new HttpError(502, "relay_rejected");
    }
  }
  throw new HttpError(503, "relayer_busy");
}
