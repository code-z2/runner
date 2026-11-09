//! Chain reads, writes, and transaction assembly over blocking RPC.
//!
//! Transport is plain JSON-RPC (`reqwest` blocking): no tokio runtime
//! crosses the FFI. Chain types (`Transaction`, keys, hashes) come from
//! `near-api-types`, so encoding bugs are the maintained crate's, not ours.

use std::{str::FromStr, time::Duration};

use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use near_api::types::{
    AccountId, CryptoHash, NearGas, NearToken, PublicKey, Signature,
};
use near_api::types::crypto::KeyType;
use near_api::types::transaction::{SignedTransaction, Transaction, TransactionV0};
use near_api::types::transaction::actions::{Action, FunctionCallAction, TransferAction};

use crate::{CoreError, hex_decode};

/// One unsigned transaction's action, in UniFFI-safe shape.
/// Yocto amounts ride as decimal strings — never floats.
#[derive(uniffi::Enum)]
pub enum TxAction {
    Transfer { amount_yocto: String },
    FunctionCall {
        method: String,
        args_json: String,
        gas: u64,
        deposit_yocto: String,
    },
}

fn parse_account(field: &str, value: &str) -> Result<AccountId, CoreError> {
    AccountId::from_str(value)
        .map_err(|e| CoreError::InvalidInput(format!("{field} is not an account id: {e}")))
}

fn parse_key(value: &str) -> Result<PublicKey, CoreError> {
    PublicKey::from_str(value)
        .map_err(|e| CoreError::InvalidInput(format!("public key invalid: {e}")))
}

fn parse_hash(value: &str) -> Result<CryptoHash, CoreError> {
    let bytes = hex_decode("block hash", value)?;
    let array: [u8; 32] = bytes
        .try_into()
        .map_err(|_| CoreError::InvalidInput("block hash must be 32 bytes".into()))?;
    Ok(CryptoHash(array))
}

fn parse_u128(field: &str, value: &str) -> Result<u128, CoreError> {
    value
        .parse::<u128>()
        .map_err(|_| CoreError::InvalidInput(format!("{field} is not a decimal integer")))
}

fn to_action(action: TxAction) -> Result<Action, CoreError> {
    match action {
        TxAction::Transfer { amount_yocto } => Ok(Action::Transfer(TransferAction {
            deposit: NearToken::from_yoctonear(parse_u128("amount", &amount_yocto)?),
        })),
        TxAction::FunctionCall {
            method,
            args_json,
            gas,
            deposit_yocto,
        } => {
            let args: serde_json::Value = serde_json::from_str(&args_json)
                .map_err(|e| CoreError::InvalidInput(format!("args are not JSON: {e}")))?;
            Ok(Action::FunctionCall(Box::new(FunctionCallAction {
                method_name: method,
                args: serde_json::to_vec(&args)
                    .map_err(|e| CoreError::InvalidInput(format!("args do not serialize: {e}")))?,
                gas: NearGas::from_gas(gas),
                deposit: NearToken::from_yoctonear(parse_u128("deposit", &deposit_yocto)?),
            })))
        }
    }
}

/// Build an unsigned V0 transaction. Returns Borsh bytes as base64.
/// V0 (no priority fee) for maximal RPC compatibility.
#[uniffi::export]
pub fn build_unsigned_tx(
    sender: String,
    receiver: String,
    public_key: String,
    nonce: u64,
    block_hash_hex: String,
    action: TxAction,
) -> Result<String, CoreError> {
    let tx = Transaction::V0(TransactionV0 {
        signer_id: parse_account("sender", &sender)?,
        public_key: parse_key(&public_key)?,
        nonce,
        receiver_id: parse_account("receiver", &receiver)?,
        block_hash: parse_hash(&block_hash_hex)?,
        actions: vec![to_action(action)?],
    });
    let bytes = borsh::to_vec(&tx).map_err(|e| CoreError::Crypto(format!("tx does not encode: {e}")))?;
    Ok(B64.encode(bytes))
}

/// The 32-byte hash the signer (local key or MPC) signs. Hex.
#[uniffi::export]
pub fn tx_signing_hash(unsigned_b64: String) -> Result<String, CoreError> {
    let raw = B64
        .decode(unsigned_b64)
        .map_err(|e| CoreError::InvalidInput(format!("tx is not base64: {e}")))?;
    let v0: TransactionV0 = borsh::from_slice(&raw)
        .map_err(|e| CoreError::InvalidInput(format!("tx does not decode: {e}")))?;
    Ok(hex::encode(Transaction::V0(v0).get_hash().0))
}

/// Attach a 64-byte signature to an unsigned tx. Returns signed Borsh as base64.
#[uniffi::export]
pub fn attach_signature(
    unsigned_b64: String,
    signature_b64: String,
    public_key: String,
) -> Result<String, CoreError> {
    let raw = B64
        .decode(unsigned_b64)
        .map_err(|e| CoreError::InvalidInput(format!("tx is not base64: {e}")))?;
    let tx: Transaction = borsh::from_slice::<TransactionV0>(&raw)
        .map(Transaction::V0)
        .map_err(|e| CoreError::InvalidInput(format!("tx does not decode: {e}")))?;
    let sig_bytes = B64
        .decode(&signature_b64)
        .map_err(|e| CoreError::InvalidInput(format!("signature is not base64: {e}")))?;
    let signature = Signature::from_parts(KeyType::ED25519, &sig_bytes)
        .map_err(|e| CoreError::InvalidInput(format!("signature malformed: {e}")))?;
    // Fail fast on wrong-key signatures: the MPC key must match the tx header.
    let expected = parse_key(&public_key)?;
    if signature.verify(tx.get_hash(), expected) == false {
        return Err(CoreError::InvalidInput("signature does not match tx public key".into()));
    }
    let signed = SignedTransaction::new(signature, tx);
    let bytes = borsh::to_vec(&signed)
        .map_err(|e| CoreError::Crypto(format!("signed tx does not encode: {e}")))?;
    Ok(B64.encode(bytes))
}

/// Outcome of a committed transaction, in app-readable shape.
#[derive(uniffi::Record)]
pub struct TxOutcome {
    pub tx_hash_hex: String,
    pub success: bool,
    pub failure: Option<String>,
}

/// Blocking JSON-RPC client. One method per call the box needs —
/// nothing else crosses the FFI.
#[derive(uniffi::Object)]
pub struct NearRpc {
    client: reqwest::blocking::Client,
    rpc_url: String,
}

#[uniffi::export]
impl NearRpc {
    #[uniffi::constructor]
    pub fn new(rpc_url: String) -> Result<Self, CoreError> {
        if !(rpc_url.starts_with("http://") || rpc_url.starts_with("https://")) {
            return Err(CoreError::InvalidInput("rpc url must be http(s)".into()));
        }
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|e| CoreError::Crypto(format!("http client failed: {e}")))?;
        Ok(Self { client, rpc_url })
    }

}

fn rpc_call(
    client: &reqwest::blocking::Client,
    rpc_url: &str,
    method: &str,
    params: serde_json::Value,
) -> Result<serde_json::Value, CoreError> {
        let body = serde_json::json!({
            "jsonrpc": "2.0", "id": "runner-near-core",
            "method": method, "params": params,
        });
        let response: serde_json::Value = client
            .post(rpc_url)
            .json(&body)
            .send()
            .map_err(|e| CoreError::Transport(format!("rpc unreachable: {e}")))?
            .json()
            .map_err(|e| CoreError::Transport(format!("rpc unreadable: {e}")))?;
        if let Some(error) = response.get("error") {
            return Err(CoreError::Chain { code: error.get("name").and_then(|n| n.as_str()).unwrap_or("rpc_error").into(), detail: error.to_string() });
        }
        response
            .get("result")
            .cloned()
            .ok_or_else(|| CoreError::Transport("rpc returned no result".into()))
}

#[uniffi::export]
impl NearRpc {
    /// Latest final block hash (hex) and height.
    pub fn latest_block(&self) -> Result<BlockRef, CoreError> {
        let result = rpc_call(&self.client, &self.rpc_url, "block", serde_json::json!({"finality": "final"}))?;
        let hash_b58 = result
            .pointer("/header/hash")
            .and_then(|h| h.as_str())
            .ok_or_else(|| CoreError::Transport("block has no hash".into()))?;
        let hash = bs58::decode(hash_b58)
            .into_vec()
            .map_err(|e| CoreError::Transport(format!("block hash not base58: {e}")))?;
        let height = result
            .pointer("/header/height")
            .and_then(|h| h.as_u64())
            .ok_or_else(|| CoreError::Transport("block has no height".into()))?;
        Ok(BlockRef {
            hash_hex: hex::encode(hash),
            height,
        })
    }

    /// Nonce + permission for an access key. Errors when the key is absent.
    pub fn access_key(&self, account_id: String, public_key: String) -> Result<AccessKeyInfo, CoreError> {
        let result = rpc_call(&self.client, &self.rpc_url, 
            "query",
            serde_json::json!({
                "request_type": "view_access_key",
                "finality": "final",
                "account_id": account_id,
                "public_key": public_key,
            }),
        )?;
        if result.get("error").is_some() {
            return Err(CoreError::Chain { code: "unknown_access_key".into(), detail: result.to_string() });
        }
        let nonce = result
            .get("nonce")
            .and_then(|n| n.as_u64())
            .ok_or_else(|| CoreError::Transport("access key has no nonce".into()))?;
        let full_access = result.get("permission").map(|p| p == "FullAccess").unwrap_or(false);
        Ok(AccessKeyInfo { nonce, full_access })
    }

    /// Raw bytes of a contract view call result.
    pub fn view_call(
        &self,
        contract_id: String,
        method: String,
        args_json: String,
    ) -> Result<Vec<u8>, CoreError> {
        let args: serde_json::Value = serde_json::from_str(&args_json)
            .map_err(|e| CoreError::InvalidInput(format!("args are not JSON: {e}")))?;
        let args_b64 = B64.encode(serde_json::to_vec(&args).map_err(|e| {
            CoreError::InvalidInput(format!("args do not serialize: {e}"))
        })?);
        let result = rpc_call(&self.client, &self.rpc_url, 
            "query",
            serde_json::json!({
                "request_type": "call_function",
                "finality": "final",
                "account_id": contract_id,
                "method_name": method,
                "args_base64": args_b64,
            }),
        )?;
        if result.get("error").is_some() {
            return Err(CoreError::Chain { code: "view_failed".into(), detail: result.to_string() });
        }
        let bytes = result
            .get("result")
            .and_then(|r| r.as_array())
            .ok_or_else(|| CoreError::Transport("view returned no bytes".into()))?
            .iter()
            .map(|b| {
                b.as_u64()
                    .and_then(|n| u8::try_from(n).ok())
                    .ok_or_else(|| CoreError::Transport("view byte out of range".into()))
            })
            .collect::<Result<Vec<u8>, _>>()?;
        Ok(bytes)
    }

    /// Broadcast a signed tx, waiting for commitment.
    pub fn broadcast_commit(&self, signed_tx_b64: String) -> Result<TxOutcome, CoreError> {
        let result = rpc_call(&self.client, &self.rpc_url, "broadcast_tx_commit", serde_json::json!([signed_tx_b64]))?;
        let tx_hash = result
            .get("transaction")
            .and_then(|t| t.get("hash"))
            .and_then(|h| h.as_str())
            .unwrap_or("")
            .to_string();
        let status = result.get("status").cloned().unwrap_or(serde_json::Value::Null);
        if let Some(failure) = status.get("Failure") {
            return Ok(TxOutcome {
                tx_hash_hex: String::new(),
                success: false,
                failure: Some(failure.to_string()),
            });
        }
        let hash_hex = if tx_hash.len() == 64 {
            // RPC returns base58; normalize to hex like everything else here.
            hex::encode(
                bs58::decode(&tx_hash).into_vec().unwrap_or_default(),
            )
        } else {
            tx_hash
        };
        Ok(TxOutcome {
            tx_hash_hex: hash_hex,
            success: true,
            failure: None,
        })
    }

    /// The MPC-derived Ed25519 key at a FastAuth path. Pure view call —
    /// no auth needed. Path shape `jwt#https://<domain>/#<sub>`,
    /// predecessor is the fast-auth contract, domain 1 is Ed25519.
    /// Verified live against `v1.signer-prod.testnet`.
    pub fn mpc_public_key(
        &self,
        mpc_contract: String,
        fast_auth_contract: String,
        path: String,
    ) -> Result<String, CoreError> {
        // Predecessor is explicit because views cannot read
        // `predecessor_account_id`. Domain 1 is Ed25519.
        let args = serde_json::json!({
            "path": path,
            "predecessor": fast_auth_contract,
            "domain_id": 1,
        });
        let bytes = self.view_call(mpc_contract, "derived_public_key".into(), args.to_string())?;
        let text = String::from_utf8(bytes)
            .map_err(|e| CoreError::Transport(format!("key is not utf8: {e}")))?;
        let key: String = serde_json::from_str(&text)
            .map_err(|e| CoreError::Transport(format!("key is not json: {e}")))?;
        if !key.starts_with("ed25519:") {
            return Err(CoreError::Transport(format!("unexpected key type: {key}")));
        }
        Ok(key)
    }

    /// Submit a `sign` call on the fast-auth contract from a funded local
    /// key (dev/testnet path). Returns the raw MPC signature bytes.
    /// Production submission rides a controlled relayer instead — same
    /// bytes, different payer.
    pub fn submit_sign_call(
        &self,
        signer_secret_b64: String,
        fast_auth_contract: String,
        guard_id: String,
        jwt: String,
        sign_payload_hex: String,
        algorithm: String,
        deposit_yocto: String,
    ) -> Result<Vec<u8>, CoreError> {
        let account_id = signer_account_from_secret(&signer_secret_b64)?;
        let public_key = signer_public_key(&signer_secret_b64)?;
        let info = self.access_key(account_id.clone(), public_key.clone())?;
        let block = self.latest_block()?;
        let payload = hex_decode("sign payload", &sign_payload_hex)?;
        let args = serde_json::json!({
            "guard_id": guard_id,
            "verify_payload": jwt,
            "sign_payload": payload,
            "algorithm": algorithm,
        });
        let unsigned = build_unsigned_tx(
            account_id.clone(),
            fast_auth_contract,
            public_key.clone(),
            info.nonce + 1,
            block.hash_hex,
            TxAction::FunctionCall {
                method: "sign".into(),
                args_json: args.to_string(),
                gas: 300_000_000_000_000,
                deposit_yocto,
            },
        )?;
        let hash = tx_signing_hash(unsigned.clone())?;
        let signature = crate::ed25519_sign(signer_secret_b64, hash)?;
        let signed = attach_signature(unsigned, signature, public_key)?;
        let outcome = self.broadcast_commit(signed)?;
        if !outcome.success {
            return Err(CoreError::Chain { code: "sign_rejected".into(), detail: outcome.failure.unwrap_or_default() });
        }
        // The MPC signature is the SuccessValue of the call result.
        let result = rpc_call(&self.client, &self.rpc_url, 
            "tx",
            serde_json::json!([outcome.tx_hash_hex, account_id]),
        )?;
        let value_b64 = result
            .pointer("/receipts_outcome/0/outcome/status/SuccessValue")
            .or_else(|| result.pointer("/status/SuccessValue"))
            .and_then(|v| v.as_str())
            .ok_or_else(|| CoreError::Transport("sign returned no value".into()))?;
        B64.decode(value_b64)
            .map_err(|e| CoreError::Transport(format!("sign value not base64: {e}")))
    }
}

fn signer_secret(secret_b64: &str) -> Result<[u8; 32], CoreError> {
    let raw = B64
        .decode(secret_b64)
        .map_err(|e| CoreError::InvalidInput(format!("secret is not base64: {e}")))?;
    raw.try_into()
        .map_err(|_| CoreError::InvalidInput("secret must be 32 bytes".into()))
}

fn signer_account_from_secret(secret_b64: &str) -> Result<String, CoreError> {
    // Dev/testnet convenience only: the implicit account of the key.
    // Production accounts are resolved, never derived here.
    let bytes = signer_secret(secret_b64)?;
    let secret = ed25519_dalek::SigningKey::from_bytes(&bytes);
    Ok(hex::encode(secret.verifying_key().to_bytes()))
}

fn signer_public_key(secret_b64: &str) -> Result<String, CoreError> {
    let bytes = signer_secret(secret_b64)?;
    let secret = ed25519_dalek::SigningKey::from_bytes(&bytes);
    Ok(format!(
        "ed25519:{}",
        bs58::encode(secret.verifying_key().to_bytes()).into_string()
    ))
}

fn tx_enum(raw: &[u8]) -> near_api::types::transaction::Transaction {
    // Re-parse through the versioned envelope for hashing.
    let v0: TransactionV0 = borsh::from_slice(raw).expect("v0 decodes");
    near_api::types::transaction::Transaction::V0(v0)
}

#[derive(uniffi::Record, Debug)]
pub struct BlockRef {
    pub hash_hex: String,
    pub height: u64,
}

#[derive(uniffi::Record, Debug)]
pub struct AccessKeyInfo {
    pub nonce: u64,
    pub full_access: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::Signer as _;
    use sha2::Digest as _;

    // RFC 8032 §7.1 TEST 1 (NEAR base58 form).
    const SECRET_B64: &str = "nWGxne/9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A=";
    const PUBKEY: &str = "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z";
    // RFC 8032 TEST 2 public key — the wrong key for rejection tests.
    const OTHER_PUBKEY: &str = "ed25519:586Z7H2vpX9qNhN2T4e9Utugie3ogjbxzGaMtM3E6HR5";
    // Fixed fake block hash: offline builds never touch the network.
    const BLOCK_HEX: &str = "9e6a3ccd4a3b5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7";

    fn transfer_unsigned() -> String {
        build_unsigned_tx(
            "alice.testnet".into(),
            "bob.testnet".into(),
            PUBKEY.into(),
            7,
            BLOCK_HEX.into(),
            TxAction::Transfer {
                amount_yocto: "1000000000000000000000000".into(),
            },
        )
        .unwrap()
    }

    #[test]
    fn transfer_builds_with_exact_fields() {
        let raw = B64.decode(transfer_unsigned()).unwrap();
        let tx: TransactionV0 = borsh::from_slice(&raw).unwrap();
        assert_eq!(tx.signer_id.as_str(), "alice.testnet");
        assert_eq!(tx.receiver_id.as_str(), "bob.testnet");
        assert_eq!(tx.nonce, 7);
        // Hash is sha256 of the Borsh bytes, computed independently here.
        let digest = sha2::Sha256::digest(&raw);
        let tx_enum = tx_enum(&raw);
        assert_eq!(tx_enum.get_hash().0, digest.as_slice());
    }

    #[test]
    fn function_call_args_round_trip() {
        let unsigned = build_unsigned_tx(
            "alice.testnet".into(),
            "treasury.testnet".into(),
            PUBKEY.into(),
            1,
            BLOCK_HEX.into(),
            TxAction::FunctionCall {
                method: "claim".into(),
                args_json: r#"{"a":1}"#.into(),
                gas: 300_000_000_000_000,
                deposit_yocto: "1".into(),
            },
        )
        .unwrap();
        let raw = B64.decode(unsigned).unwrap();
        let tx: TransactionV0 = borsh::from_slice(&raw).unwrap();
        match &tx.actions[..] {
            [Action::FunctionCall(action)] => {
                assert_eq!(action.method_name, "claim");
                assert_eq!(action.args, br#"{"a":1}"#);
                assert_eq!(action.gas.as_gas(), 300_000_000_000_000);
                assert_eq!(action.deposit.as_yoctonear(), 1);
            }
            other => panic!("unexpected actions: {other:?}"),
        }
    }

    #[test]
    fn sign_hash_attach_round_trip() {
        let unsigned = transfer_unsigned();
        let hash_hex = tx_signing_hash(unsigned.clone()).unwrap();
        assert_eq!(hash_hex.len(), 64);
        // Sign with dalek directly — independent of the core's own signer.
        let secret = ed25519_dalek::SigningKey::from_bytes(
            &B64.decode(SECRET_B64).unwrap().try_into().unwrap(),
        );
        let sig = secret.sign(&hex::decode(&hash_hex).unwrap());
        let sig_b64 = B64.encode(sig.to_bytes());
        let signed_b64 =
            attach_signature(unsigned.clone(), sig_b64.clone(), PUBKEY.into()).unwrap();
        let signed = B64.decode(signed_b64).unwrap();
        let unsigned_raw = B64.decode(unsigned).unwrap();
        // Wire layout: unsigned tx bytes, then 0x00 (ED25519 tag) + 64-byte sig.
        assert!(signed.starts_with(&unsigned_raw));
        let tail = &signed[unsigned_raw.len()..];
        assert_eq!(tail.len(), 65);
        assert_eq!(tail[0], 0);
        assert_eq!(&tail[1..], &sig.to_bytes());
        // And the embedded signature verifies through the public path.
        let core_sig = crate::ed25519_sign(SECRET_B64.into(), hash_hex.clone()).unwrap();
        assert_eq!(core_sig, sig_b64);
        assert!(crate::ed25519_verify(PUBKEY.into(), hash_hex, core_sig).unwrap());
    }

    #[test]
    fn attach_rejects_wrong_key_signature() {
        let unsigned = transfer_unsigned();
        let hash_hex = tx_signing_hash(unsigned.clone()).unwrap();
        let secret = ed25519_dalek::SigningKey::from_bytes(
            &B64.decode(SECRET_B64).unwrap().try_into().unwrap(),
        );
        let sig = secret.sign(&hex::decode(&hash_hex).unwrap());
        let err = attach_signature(unsigned, B64.encode(sig.to_bytes()), OTHER_PUBKEY.into())
            .unwrap_err();
        assert!(matches!(err, CoreError::InvalidInput(_)));
    }

    #[test]
    fn builders_reject_bad_input() {
        assert!(build_unsigned_tx(
            "NOT AN ACCOUNT!!!".into(),
            "bob.testnet".into(),
            PUBKEY.into(),
            1,
            BLOCK_HEX.into(),
            TxAction::Transfer { amount_yocto: "1".into() },
        )
        .is_err());
        assert!(build_unsigned_tx(
            "alice.testnet".into(),
            "bob.testnet".into(),
            PUBKEY.into(),
            1,
            BLOCK_HEX.into(),
            TxAction::Transfer { amount_yocto: "1.5".into() },
        )
        .is_err());
        assert!(build_unsigned_tx(
            "alice.testnet".into(),
            "bob.testnet".into(),
            PUBKEY.into(),
            1,
            "zz".into(),
            TxAction::Transfer { amount_yocto: "1".into() },
        )
        .is_err());
        assert!(tx_signing_hash("!!!".into()).is_err());
    }

    fn testnet() -> NearRpc {
        NearRpc::new("https://rpc.testnet.near.org".into()).unwrap()
    }

    /// Live: final block parses. Needs network; run explicitly.
    #[test]
    #[ignore]
    fn live_latest_block_parses() {
        let block = testnet().latest_block().unwrap();
        assert!(block.height > 200_000_000);
        assert_eq!(block.hash_hex.len(), 64);
    }

    /// Live: MPC derivation is stable and Ed25519. Needs network.
    #[test]
    #[ignore]
    fn live_mpc_derivation_stable_ed25519() {
        let rpc = testnet();
        let path = "jwt#https://login.testnet.fast-auth.com/#probe-runner-near".to_string();
        let first = rpc
            .mpc_public_key(
                "v1.signer-prod.testnet".into(),
                "fast-auth.testnet".into(),
                path.clone(),
            )
            .unwrap();
        let second = rpc
            .mpc_public_key(
                "v1.signer-prod.testnet".into(),
                "fast-auth.testnet".into(),
                path,
            )
            .unwrap();
        assert!(first.starts_with("ed25519:"));
        assert_eq!(first, second);
    }

    /// Live: unknown access keys fail closed with a typed chain error.
    #[test]
    #[ignore]
    fn live_unknown_access_key_errors() {
        let err = testnet()
            .access_key("alice.testnet".into(), PUBKEY.into())
            .unwrap_err();
        assert!(matches!(err, CoreError::Chain { .. }));
    }
}
