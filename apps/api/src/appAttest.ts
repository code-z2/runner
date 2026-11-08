import "reflect-metadata";
import { X509Certificate } from "@peculiar/x509";
import { decode } from "cbor-x";
import { p256 } from "@noble/curves/nist.js";
import { concat, hash, sameBytes, utf8 } from "./codec";
import { HttpError } from "./http";

const APPLE_APP_ATTESTATION_ROOT = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const NONCE_EXTENSION = "1.2.840.113635.100.8.2";
const NONCE_EXTENSION_PREFIX = new Uint8Array([0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]);

const AAGUIDS: Record<string, Uint8Array> = {
  production: concat(utf8("appattest"), new Uint8Array(7)),
  development: utf8("appattestdevelop"),
};

interface AuthenticatorData {
  rpIdHash: Uint8Array;
  counter: number;
  aaguid?: Uint8Array;
  credentialId?: Uint8Array;
}

function parseAuthenticatorData(data: Uint8Array, withCredential: boolean): AuthenticatorData {
  if (data.length < 37) {
    throw new HttpError(401, "invalid_authenticator_data");
  }
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const parsed: AuthenticatorData = { rpIdHash: data.slice(0, 32), counter: view.getUint32(33) };
  if (withCredential) {
    if (data.length < 55) {
      throw new HttpError(401, "invalid_authenticator_data");
    }
    const length = view.getUint16(53);
    if (data.length < 55 + length) {
      throw new HttpError(401, "invalid_authenticator_data");
    }
    parsed.aaguid = data.slice(37, 53);
    parsed.credentialId = data.slice(55, 55 + length);
  }
  return parsed;
}

function decodeCbor(data: Uint8Array): Record<string, unknown> {
  let value: unknown;
  try {
    value = decode(data);
  } catch {
    throw new HttpError(400, "invalid_cbor");
  }
  if (typeof value !== "object" || value === null) {
    throw new HttpError(400, "invalid_cbor");
  }
  return value as Record<string, unknown>;
}

function asBytes(value: unknown): Uint8Array {
  if (!(value instanceof Uint8Array)) {
    throw new HttpError(401, "invalid_attestation");
  }
  return new Uint8Array(value);
}

function withinValidity(certificate: X509Certificate, now: Date): boolean {
  return certificate.notBefore <= now && now <= certificate.notAfter;
}

export interface KeyAttestationInput {
  attestation: Uint8Array;
  challenge: Uint8Array;
  keyId: Uint8Array;
  appId: string;
  environment: string;
  now: Date;
}

export async function verifyKeyAttestation(input: KeyAttestationInput): Promise<Uint8Array> {
  const object = decodeCbor(input.attestation);
  const statement = object.attStmt as Record<string, unknown> | undefined;
  if (object.fmt !== "apple-appattest" || !statement || !Array.isArray(statement.x5c) || statement.x5c.length < 2) {
    throw new HttpError(401, "invalid_attestation");
  }
  const authData = asBytes(object.authData);
  const leaf = new X509Certificate(asBytes(statement.x5c[0]));
  const intermediate = new X509Certificate(asBytes(statement.x5c[1]));
  const root = new X509Certificate(APPLE_APP_ATTESTATION_ROOT);

  const chainValid =
    [leaf, intermediate, root].every((certificate) => withinValidity(certificate, input.now)) &&
    (await intermediate.verify({ publicKey: root.publicKey, signatureOnly: true })) &&
    (await leaf.verify({ publicKey: intermediate.publicKey, signatureOnly: true }));
  if (!chainValid) {
    throw new HttpError(401, "untrusted_certificate");
  }

  const nonce = hash(concat(authData, hash(input.challenge)));
  const extension = leaf.getExtension(NONCE_EXTENSION);
  if (!extension || !sameBytes(new Uint8Array(extension.value), concat(NONCE_EXTENSION_PREFIX, nonce))) {
    throw new HttpError(401, "nonce_mismatch");
  }

  const publicKeyHandle = await leaf.publicKey.export({ name: "ECDSA", namedCurve: "P-256" }, ["verify"]);
  const publicKey = new Uint8Array((await crypto.subtle.exportKey("raw", publicKeyHandle)) as ArrayBuffer);
  if (!sameBytes(hash(publicKey), input.keyId)) {
    throw new HttpError(401, "key_id_mismatch");
  }

  const parsed = parseAuthenticatorData(authData, true);
  const expectedAaguid = AAGUIDS[input.environment];
  if (
    !sameBytes(parsed.rpIdHash, hash(utf8(input.appId))) ||
    parsed.counter !== 0 ||
    !expectedAaguid ||
    !sameBytes(parsed.aaguid!, expectedAaguid) ||
    !sameBytes(parsed.credentialId!, input.keyId)
  ) {
    throw new HttpError(401, "invalid_authenticator_data");
  }
  return publicKey;
}

export interface AssertionInput {
  assertion: Uint8Array;
  clientData: Uint8Array;
  publicKey: Uint8Array;
  previousCounter: number;
  appId: string;
}

export function verifyAssertion(input: AssertionInput): number {
  const object = decodeCbor(input.assertion);
  if (!(object.signature instanceof Uint8Array) || !(object.authenticatorData instanceof Uint8Array)) {
    throw new HttpError(401, "invalid_assertion");
  }
  const authData = new Uint8Array(object.authenticatorData);
  const nonce = hash(concat(authData, hash(input.clientData)));
  let valid = false;
  try {
    valid = p256.verify(new Uint8Array(object.signature), nonce, input.publicKey, { format: "der", lowS: false });
  } catch {
    valid = false;
  }
  if (!valid) {
    throw new HttpError(401, "invalid_assertion");
  }
  const parsed = parseAuthenticatorData(authData, false);
  if (!sameBytes(parsed.rpIdHash, hash(utf8(input.appId))) || parsed.counter <= input.previousCounter) {
    throw new HttpError(401, "invalid_assertion");
  }
  return parsed.counter;
}
