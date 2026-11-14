//! 1Click (NEAR Intents) quote codec: build SDK-exact quote requests and
//! decode quote responses with the official `oneclick` models.
//!
//! Transport lives behind the Worker proxy (/v1/intents/*); nothing here
//! touches the network.

use oneclick::models::{Quote, QuoteRequest};
use serde::de::DeserializeOwned;

use crate::CoreError;

/// Quote parameters. Enum-like fields carry the 1Click wire values
/// (`EXACT_OUTPUT`, `ORIGIN_CHAIN`, ...) and are checked against the SDK.
#[derive(uniffi::Record, Debug)]
pub struct IntentQuoteRequest {
    pub dry: bool,
    pub swap_type: String,
    pub slippage_bps: u32,
    pub origin_asset: String,
    pub deposit_type: String,
    pub destination_asset: String,
    pub amount: String,
    pub refund_to: String,
    pub refund_type: String,
    pub recipient: String,
    pub recipient_type: String,
    pub deadline: String,
    /// `msg` for the `ft_transfer_call` that delivers to `recipient`.
    pub custom_recipient_msg: Option<String>,
}

#[derive(uniffi::Record, Debug)]
pub struct IntentQuote {
    pub deposit_address: Option<String>,
    pub deposit_memo: Option<String>,
    pub amount_in: String,
    pub amount_out: String,
    pub min_amount_out: String,
    pub deadline: Option<String>,
    pub time_estimate_secs: f64,
}

/// Wire string -> SDK enum, using the SDK's own serde names.
fn wire<T: DeserializeOwned>(field: &str, value: &str) -> Result<T, CoreError> {
    serde_json::from_value(serde_json::Value::String(value.to_owned()))
        .map_err(|_| CoreError::InvalidInput(format!("unsupported {field}: {value}")))
}

#[uniffi::export]
pub fn encode_intent_quote(req: IntentQuoteRequest) -> Result<Vec<u8>, CoreError> {
    let body = QuoteRequest {
        dry: req.dry,
        swap_type: wire("swap type", &req.swap_type)?,
        slippage_tolerance: req.slippage_bps as f64,
        origin_asset: req.origin_asset,
        deposit_type: wire("deposit type", &req.deposit_type)?,
        destination_asset: req.destination_asset,
        amount: req.amount,
        refund_to: req.refund_to,
        refund_type: wire("refund type", &req.refund_type)?,
        recipient: req.recipient,
        recipient_type: wire("recipient type", &req.recipient_type)?,
        deadline: req.deadline,
        custom_recipient_msg: req.custom_recipient_msg,
        ..Default::default()
    };
    serde_json::to_vec(&body).map_err(|e| CoreError::InvalidInput(format!("quote request: {e}")))
}

#[uniffi::export]
pub fn decode_intent_quote(body: Vec<u8>) -> Result<IntentQuote, CoreError> {
    #[derive(serde::Deserialize)]
    struct Envelope {
        quote: Quote,
    }
    let Envelope { quote } = serde_json::from_slice(&body)
        .map_err(|e| CoreError::Transport(format!("quote response: {e}")))?;
    Ok(IntentQuote {
        deposit_address: quote.deposit_address,
        deposit_memo: quote.deposit_memo,
        amount_in: quote.amount_in,
        amount_out: quote.amount_out,
        min_amount_out: quote.min_amount_out,
        deadline: quote.deadline,
        time_estimate_secs: quote.time_estimate,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request() -> IntentQuoteRequest {
        IntentQuoteRequest {
            dry: false,
            swap_type: "EXACT_OUTPUT".into(),
            slippage_bps: 100,
            origin_asset: "a".into(),
            deposit_type: "ORIGIN_CHAIN".into(),
            destination_asset: "b".into(),
            amount: "1".into(),
            refund_to: "r".into(),
            refund_type: "ORIGIN_CHAIN".into(),
            recipient: "escrow.near".into(),
            recipient_type: "DESTINATION_CHAIN".into(),
            deadline: "d".into(),
            custom_recipient_msg: Some(r#"{"owner":"o"}"#.into()),
        }
    }

    #[test]
    fn encodes_sdk_request_with_recipient_msg() {
        let body: serde_json::Value =
            serde_json::from_slice(&encode_intent_quote(request()).unwrap()).unwrap();
        assert_eq!(body["swapType"], "EXACT_OUTPUT");
        assert_eq!(body["slippageTolerance"], 100.0);
        assert_eq!(body["customRecipientMsg"], r#"{"owner":"o"}"#);
        assert!(body.get("referral").is_none());
    }

    #[test]
    fn rejects_unknown_wire_values() {
        let mut bad = request();
        bad.swap_type = "SOMETHING".into();
        assert!(encode_intent_quote(bad).is_err());
    }

    #[test]
    fn decodes_quote_with_memo() {
        let body = serde_json::json!({
            "timestamp": "t", "signature": "s", "quoteRequest": {},
            "quote": {
                "depositAddress": "0xabc", "depositMemo": "m", "amountIn": "1",
                "amountInFormatted": "1", "amountInUsd": "1", "minAmountIn": "1",
                "amountOut": "2", "amountOutFormatted": "2", "amountOutUsd": "2",
                "minAmountOut": "2", "deadline": "2026-01-01T00:00:00Z", "timeEstimate": 12.5
            }
        });
        let quote = decode_intent_quote(serde_json::to_vec(&body).unwrap()).unwrap();
        assert_eq!(quote.deposit_address.as_deref(), Some("0xabc"));
        assert_eq!(quote.deposit_memo.as_deref(), Some("m"));
        assert_eq!(quote.amount_out, "2");
    }
}
