import { ed25519 } from "@noble/curves/ed25519.js";
import { concat, fromBase58, fromBase64, hash, toBase64, utf8 } from "./codec";
import { HttpError } from "./http";

const NEP413_TAG = 2 ** 31 + 413;
const ACCOUNT_ID = /^(([a-z\d]+[-_])*[a-z\d]+\.)*([a-z\d]+[-_])*[a-z\d]+$/;

export function isAccountId(value: string): boolean {
  return value.length >= 2 && value.length <= 64 && ACCOUNT_ID.test(value);
}

function u32(value: number): Uint8Array {
  const bytes = new Uint8Array(4);
  new DataView(bytes.buffer).setUint32(0, value, true);
  return bytes;
}

function borshString(value: string): Uint8Array {
  const bytes = utf8(value);
  return concat(u32(bytes.length), bytes);
}

export function nep413Digest(message: string, nonce: Uint8Array, recipient: string): Uint8Array {
  return hash(concat(u32(NEP413_TAG), borshString(message), nonce, borshString(recipient), new Uint8Array([0])));
}

export function parsePublicKey(value: string): Uint8Array {
  if (!value.startsWith("ed25519:")) {
    throw new HttpError(400, "invalid_near_public_key");
  }
  const key = fromBase58(value.slice("ed25519:".length), "invalid_near_public_key");
  if (key.length !== 32) {
    throw new HttpError(400, "invalid_near_public_key");
  }
  return key;
}

export function verifyNep413(input: {
  message: string;
  nonce: Uint8Array;
  recipient: string;
  publicKey: Uint8Array;
  signature: string;
}): boolean {
  const signature = fromBase64(input.signature, "invalid_near_signature");
  if (signature.length !== 64 || input.nonce.length !== 32) {
    return false;
  }
  try {
    return ed25519.verify(signature, nep413Digest(input.message, input.nonce, input.recipient), input.publicKey);
  } catch {
    return false;
  }
}

async function rpcQuery(rpcUrl: string, params: Record<string, unknown>): Promise<Record<string, unknown> | null> {
  let response: Response;
  try {
    response = await fetch(rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: "runner-api", method: "query", params: { finality: "final", ...params } }),
    });
  } catch {
    throw new HttpError(502, "near_rpc_unavailable");
  }
  if (!response.ok) {
    throw new HttpError(502, "near_rpc_unavailable");
  }
  const body = (await response.json()) as { result?: Record<string, unknown>; error?: unknown };
  if (body.error || !body.result || "error" in body.result) {
    return null;
  }
  return body.result;
}

export interface AccessKeyView {
  nonce: bigint;
  fullAccess: boolean;
  blockHash: string;
  blockHeight: bigint;
}

export async function viewAccessKey(rpcUrl: string, accountId: string, publicKey: string): Promise<AccessKeyView | null> {
  const result = await rpcQuery(rpcUrl, {
    request_type: "view_access_key",
    account_id: accountId,
    public_key: publicKey,
  });
  if (!result || result.nonce === undefined || typeof result.block_hash !== "string") {
    return null;
  }
  return {
    nonce: BigInt(result.nonce as number | string),
    fullAccess: result.permission === "FullAccess",
    blockHash: result.block_hash,
    blockHeight: BigInt(result.block_height as number | string),
  };
}

export async function isFullAccessKey(rpcUrl: string, accountId: string, publicKey: string): Promise<boolean> {
  return (await viewAccessKey(rpcUrl, accountId, publicKey))?.fullAccess === true;
}

export interface AccountView {
  amount: bigint;
  locked: bigint;
}

export async function viewAccount(rpcUrl: string, accountId: string): Promise<AccountView | null> {
  const result = await rpcQuery(rpcUrl, { request_type: "view_account", account_id: accountId });
  if (!result || typeof result.amount !== "string") {
    return null;
  }
  return { amount: BigInt(result.amount as string), locked: BigInt((result.locked as string | undefined) ?? "0") };
}

export async function rpcCall(rpcUrl: string, method: string, params: unknown): Promise<{ result?: Record<string, unknown>; error?: Record<string, unknown> }> {
  let response: Response;
  try {
    response = await fetch(rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: "runner-api", method, params }),
    });
  } catch {
    throw new HttpError(502, "near_rpc_unavailable");
  }
  if (!response.ok && response.status !== 400) {
    throw new HttpError(502, "near_rpc_unavailable");
  }
  return (await response.json()) as { result?: Record<string, unknown>; error?: Record<string, unknown> };
}

export async function isRegisteredMerchant(rpcUrl: string, contractId: string, merchantId: string): Promise<boolean> {
  const result = await rpcQuery(rpcUrl, {
    request_type: "call_function",
    account_id: contractId,
    method_name: "is_merchant",
    args_base64: toBase64(utf8(JSON.stringify({ account_id: merchantId }))),
  });
  if (!result || !Array.isArray(result.result)) {
    return false;
  }
  try {
    return JSON.parse(new TextDecoder().decode(new Uint8Array(result.result as number[]))) === true;
  } catch {
    return false;
  }
}
