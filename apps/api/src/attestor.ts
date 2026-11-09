import { ed25519 } from "@noble/curves/ed25519.js";
import { fromBase64, randomBytes, toBase64, toHex, utf8 } from "./codec";
import { HttpError } from "./http";

export interface ClaimPass {
  accountId: string;
  activityHash: string;
  maxAmountCents: number;
  expiresAt: number;
}

export interface SignedClaimPass {
  attestation: string;
  signature: string;
}

export function attestorSecret(encoded: string): Uint8Array {
  let secret: Uint8Array;
  try {
    secret = fromBase64(encoded, "attestor_key_invalid");
  } catch {
    throw new HttpError(500, "attestor_key_invalid");
  }
  if (secret.length !== 32) {
    throw new HttpError(500, "attestor_key_invalid");
  }
  return secret;
}

export interface RunProof {
  accountId: string;
  activityHash: string;
  startedAt: number;
  endedAt: number;
  distanceM: number;
  activeSeconds: number;
}

export function signRunProof(run: RunProof, secret: Uint8Array): SignedClaimPass {
  const proof = JSON.stringify({
    v: 1,
    kind: "run",
    account_id: run.accountId,
    activity_hash: run.activityHash,
    started_at: run.startedAt,
    ended_at: run.endedAt,
    distance_m: run.distanceM,
    active_seconds: run.activeSeconds,
  });
  return { attestation: proof, signature: toBase64(ed25519.sign(utf8(proof), secret)) };
}

export function signClaimPass(pass: ClaimPass, secret: Uint8Array): SignedClaimPass {
  const attestation = JSON.stringify({
    v: 1,
    account_id: pass.accountId,
    activity_hash: pass.activityHash,
    max_amount_cents: pass.maxAmountCents,
    expires_at: pass.expiresAt,
    nonce: toHex(randomBytes(32)),
  });
  return { attestation, signature: toBase64(ed25519.sign(utf8(attestation), secret)) };
}
