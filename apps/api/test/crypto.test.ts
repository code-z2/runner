import { describe, expect, test } from "bun:test";
import { ed25519 } from "@noble/curves/ed25519.js";
import { p256 } from "@noble/curves/nist.js";
import { base58 } from "@scure/base";
import { encode } from "cbor-x";
import { verifyAssertion, verifyKeyAttestation } from "../src/appAttest";
import { signClaimPass } from "../src/attestor";
import { toBase64, utf8 } from "../src/codec";
import { geohash } from "../src/geohash";
import { isAccountId, nep413Digest, parsePublicKey, verifyNep413 } from "../src/near";
import { makeAssertion } from "./support";

const appId = "TEAMID1234.com.runner.app";

describe("verifyAssertion", () => {
  const secret = p256.utils.randomSecretKey();
  const publicKey = p256.getPublicKey(secret, false);
  const clientData = utf8('{"account_id":"runner.ije.near"}');

  test("accepts a valid assertion and returns the new counter", () => {
    const assertion = makeAssertion(secret, clientData, 5);
    expect(verifyAssertion({ assertion, clientData, publicKey, previousCounter: 4, appId })).toBe(5);
  });

  test("rejects a counter that did not go up", () => {
    const assertion = makeAssertion(secret, clientData, 4);
    expect(() => verifyAssertion({ assertion, clientData, publicKey, previousCounter: 4, appId })).toThrow(
      "invalid_assertion",
    );
  });

  test("rejects a different payload", () => {
    const assertion = makeAssertion(secret, clientData, 5);
    expect(() =>
      verifyAssertion({ assertion, clientData: utf8("{}"), publicKey, previousCounter: 0, appId }),
    ).toThrow("invalid_assertion");
  });

  test("rejects another app id", () => {
    const assertion = makeAssertion(secret, clientData, 5, "OTHER.com.other.app");
    expect(() => verifyAssertion({ assertion, clientData, publicKey, previousCounter: 0, appId })).toThrow(
      "invalid_assertion",
    );
  });
});

describe("NEP-413", () => {
  const secret = ed25519.utils.randomSecretKey();
  const publicKey = ed25519.getPublicKey(secret);
  const nonce = new Uint8Array(32).fill(9);

  test("verifies a signed message", () => {
    const signature = toBase64(ed25519.sign(nep413Digest("hello", nonce, "runner-api"), secret));
    expect(verifyNep413({ message: "hello", nonce, recipient: "runner-api", publicKey, signature })).toBe(true);
  });

  test("rejects a signature for another recipient", () => {
    const signature = toBase64(ed25519.sign(nep413Digest("hello", nonce, "other-app"), secret));
    expect(verifyNep413({ message: "hello", nonce, recipient: "runner-api", publicKey, signature })).toBe(false);
  });

  test("parses ed25519 public keys", () => {
    expect(parsePublicKey(`ed25519:${base58.encode(publicKey)}`)).toEqual(publicKey);
    expect(() => parsePublicKey("secp256k1:abc")).toThrow("invalid_near_public_key");
  });

  test("checks account ids", () => {
    expect(isAccountId("runner.ije.near")).toBe(true);
    expect(isAccountId("a".repeat(64))).toBe(true);
    expect(isAccountId("Runner.near")).toBe(false);
    expect(isAccountId("bad..near")).toBe(false);
  });
});

describe("signClaimPass", () => {
  test("signs the exact attestation bytes", () => {
    const secret = new Uint8Array(32).fill(7);
    const pass = signClaimPass(
      { accountId: "runner.ije.near", activityHash: "ab".repeat(32), maxAmountCents: 256, expiresAt: 1_800_007_200 },
      secret,
    );
    const fields = JSON.parse(pass.attestation);
    expect(Object.keys(fields)).toEqual(["v", "account_id", "activity_hash", "max_amount_cents", "expires_at", "nonce"]);
    expect(fields.max_amount_cents).toBe(256);
    expect(
      ed25519.verify(Buffer.from(pass.signature, "base64"), utf8(pass.attestation), ed25519.getPublicKey(secret)),
    ).toBe(true);
  });
});

describe("geohash", () => {
  test("matches known cells", () => {
    expect(geohash(57.64911, 10.40744)).toBe("u4pru");
    expect(geohash(42.6, -5.6)).toBe("ezs42");
  });
});

describe("verifyKeyAttestation", () => {
  const input = {
    challenge: new Uint8Array(32),
    keyId: new Uint8Array(32),
    appId,
    environment: "production",
    now: new Date(),
  };

  test("rejects bytes that are not CBOR", async () => {
    await expect(verifyKeyAttestation({ ...input, attestation: new Uint8Array([0xff, 0x00]) })).rejects.toThrow(
      "invalid_cbor",
    );
  });

  test("rejects attestations that are not from Apple App Attest", async () => {
    const attestation = encode({ fmt: "packed", attStmt: { x5c: [] }, authData: new Uint8Array(37) });
    await expect(verifyKeyAttestation({ ...input, attestation })).rejects.toThrow("invalid_attestation");
  });
});
