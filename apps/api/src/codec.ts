import { base58, base64 } from "@scure/base";
import { sha256 } from "@noble/hashes/sha2.js";
import { bytesToHex, concatBytes } from "@noble/hashes/utils.js";
import { HttpError } from "./http";

export const utf8 = (text: string): Uint8Array => new TextEncoder().encode(text);

export const hash = (data: Uint8Array): Uint8Array => sha256(data);

export const hashHex = (data: Uint8Array): string => bytesToHex(sha256(data));

export const toHex = bytesToHex;

export const concat = concatBytes;

export const toBase64 = (data: Uint8Array): string => base64.encode(data);

export function fromBase64(text: string, code: string): Uint8Array {
  try {
    return base64.decode(text);
  } catch {
    throw new HttpError(400, code);
  }
}

export function fromBase58(text: string, code: string): Uint8Array {
  try {
    return base58.decode(text);
  } catch {
    throw new HttpError(400, code);
  }
}

export function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

export const randomBytes = (length: number): Uint8Array => crypto.getRandomValues(new Uint8Array(length));

export const randomToken = (): string => toHex(randomBytes(32));
