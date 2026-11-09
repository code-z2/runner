//! runner-near-core: the only chain logic in the app.
//!
//! Pure crypto and codec functions plus (next) RPC and MPC signing, all
//! behind a UniFFI seam so Swift calls one audited box. Byte-exact with
//! `apps/api/src/near.ts` — the server is the other half of every digest
//! here, so vectors are shared, not re-derived.

use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use ed25519_dalek::{Signer as _, SigningKey, Verifier as _, VerifyingKey};
use sha2::{Digest as _, Sha256};

uniffi::setup_scaffolding!();

pub mod chain;
pub mod intents;

pub use chain::{AccessKeyInfo, BlockRef, NearRpc, TxAction, TxOutcome};
pub use intents::{IntentQuote, IntentQuoteRequest, IntentStatus, IntentStatusReport, IntentToken, NearIntents};

/// Every failure mode of the core, typed once.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum CoreError {
    #[error("invalid input: {0}")]
    InvalidInput(String),
    #[error("crypto failure: {0}")]
    Crypto(String),
    #[error("transport failure: {0}")]
    Transport(String),
    #[error("chain rejected ({code}): {detail}")]
    Chain { code: String, detail: String },
}

fn b64_decode(field: &str, value: &str) -> Result<Vec<u8>, CoreError> {
    B64.decode(value)
        .map_err(|e| CoreError::InvalidInput(format!("{field} is not base64: {e}")))
}

fn hex_decode(field: &str, value: &str) -> Result<Vec<u8>, CoreError> {
    hex::decode(value).map_err(|e| CoreError::InvalidInput(format!("{field} is not hex: {e}")))
}

fn ed25519_public_key(value: &str) -> Result<VerifyingKey, CoreError> {
    let raw = value
        .strip_prefix("ed25519:")
        .ok_or_else(|| CoreError::InvalidInput("public key must start with ed25519:".into()))?;
    let bytes = bs58::decode(raw)
        .into_vec()
        .map_err(|e| CoreError::InvalidInput(format!("public key is not base58: {e}")))?;
    VerifyingKey::try_from(bytes.as_slice())
        .map_err(|e| CoreError::InvalidInput(format!("public key is not 32 bytes: {e}")))
}

/// NEP-413 digest, byte-identical to `nep413Digest` in `apps/api`:
/// sha256(LE-u32(2^31+413) || borsh(message) || nonce || borsh(recipient) || 0x00).
#[uniffi::export]
pub fn nep413_digest_hex(
    message: String,
    nonce_b64: String,
    recipient: String,
) -> Result<String, CoreError> {
    let nonce = b64_decode("nonce", &nonce_b64)?;
    if nonce.len() != 32 {
        return Err(CoreError::InvalidInput("nonce must be 32 bytes".into()));
    }
    let mut payload = Vec::with_capacity(4 + 4 + message.len() + 32 + 4 + recipient.len() + 1);
    payload.extend_from_slice(&(2u32.pow(31) + 413).to_le_bytes());
    payload.extend_from_slice(&(message.len() as u32).to_le_bytes());
    payload.extend_from_slice(message.as_bytes());
    payload.extend_from_slice(&nonce);
    payload.extend_from_slice(&(recipient.len() as u32).to_le_bytes());
    payload.extend_from_slice(recipient.as_bytes());
    payload.push(0);
    Ok(hex::encode(Sha256::digest(&payload)))
}

/// A fresh Ed25519 keypair. Secret is base64 seed; public key is the
/// `ed25519:<base58>` NEAR form.
#[derive(uniffi::Record)]
pub struct EdKeypair {
    pub secret_b64: String,
    pub public_key: String,
}

#[uniffi::export]
pub fn ed25519_keypair() -> Result<EdKeypair, CoreError> {
    let mut rng = rand_core::OsRng;
    let secret = SigningKey::generate(&mut rng);
    Ok(EdKeypair {
        secret_b64: B64.encode(secret.to_bytes()),
        public_key: format!("ed25519:{}", bs58::encode(secret.verifying_key().to_bytes()).into_string()),
    })
}

#[uniffi::export]
pub fn ed25519_sign(secret_b64: String, message_hex: String) -> Result<String, CoreError> {
    let raw = b64_decode("secret", &secret_b64)?;
    let bytes: [u8; 32] = raw
        .try_into()
        .map_err(|_| CoreError::InvalidInput("secret must be 32 bytes".into()))?;
    let secret = SigningKey::from_bytes(&bytes);
    let message = hex_decode("message", &message_hex)?;
    Ok(B64.encode(secret.sign(&message).to_bytes()))
}

#[uniffi::export]
pub fn ed25519_verify(
    public_key: String,
    message_hex: String,
    signature_b64: String,
) -> Result<bool, CoreError> {
    let key = ed25519_public_key(&public_key)?;
    let message = hex_decode("message", &message_hex)?;
    let raw = b64_decode("signature", &signature_b64)?;
    let bytes: [u8; 64] = raw
        .try_into()
        .map_err(|_| CoreError::InvalidInput("signature must be 64 bytes".into()))?;
    let signature = ed25519_dalek::Signature::from_bytes(&bytes);
    Ok(key.verify(&message, &signature).is_ok())
}

/// Implicit account id for a key: hex of the 32 public-key bytes.
#[uniffi::export]
pub fn implicit_account_id(public_key: String) -> Result<String, CoreError> {
    let key = ed25519_public_key(&public_key)?;
    Ok(hex::encode(key.to_bytes()))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Minted from `apps/api/src/near.ts` (`bun -e`): message
    /// "hello runner", nonce 32x0x07, recipient "runner-api".
    #[test]
    fn nep413_matches_server_vector() {
        let digest = nep413_digest_hex(
            "hello runner".into(),
            "BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=".into(),
            "runner-api".into(),
        )
        .unwrap();
        assert_eq!(
            digest,
            "1b2b2ba6fa70730b76c6a75789e4b0efb43b02407c5ed1e6c54415b6d85a1b66"
        );
    }

    #[test]
    fn nep413_rejects_short_nonce() {
        assert!(nep413_digest_hex("m".into(), B64.encode([1u8; 31]), "r".into()).is_err());
    }

    /// RFC 8032 section 7.1 TEST 1, copied verbatim from rfc-editor.org.
    #[test]
    fn ed25519_matches_rfc8032() {
        let secret_hex = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";
        let secret_b64 = B64.encode(hex::decode(secret_hex).unwrap());
        let public_key =
            "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z";
        let sig = ed25519_sign(secret_b64, "".into()).unwrap();
        let expected = B64.encode(
            hex::decode(
                "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
            )
            .unwrap(),
        );
        assert_eq!(sig, expected);
        assert!(ed25519_verify(public_key.into(), "".into(), sig).unwrap());
        assert!(!ed25519_verify(public_key.into(), "00".into(), expected).unwrap());
    }

    #[test]
    fn keypair_round_trips() {
        let pair = ed25519_keypair().unwrap();
        let sig = ed25519_sign(pair.secret_b64.clone(), "ab".into()).unwrap();
        assert!(ed25519_verify(pair.public_key.clone(), "ab".into(), sig).unwrap());
        assert_eq!(implicit_account_id(pair.public_key).unwrap().len(), 64);
    }

    #[test]
    fn rejects_malformed_keys() {
        assert!(ed25519_public_key("d75a9801").is_err());
        assert!(ed25519_public_key("ed25519:not-base58!!").is_err());
    }
}
