//! 1Click (NEAR Intents) swap rail: token list, quotes, deposit notices,
//! execution status.
//!
//! Contract types come from the official `one-click-sdk-rs` crate, but the
//! generated endpoint functions never attach partner auth — so every call
//! goes through our own blocking client with `X-API-Key`, exactly like the
//! RPC layer: no tokio runtime crosses the FFI.

use std::time::Duration;

use one_click_sdk_rs::models::get_execution_status_response::Status as SdkStatus;
use one_click_sdk_rs::models::quote_request::{
    DepositType as SdkDepositType, QuoteRequest as SdkQuoteRequest,
    RecipientType as SdkRecipientType, RefundType as SdkRefundType, SwapType as SdkSwapType,
};
use one_click_sdk_rs::models::submit_deposit_tx_request::SubmitDepositTxRequest as SdkSubmitRequest;
use one_click_sdk_rs::models::submit_deposit_tx_response::Status as SdkSubmitStatus;

use crate::CoreError;

/// One swappable asset, in UniFFI-safe shape. Amounts ride as decimal
/// strings everywhere else; only the static `decimals` count is numeric.
#[derive(uniffi::Record, Debug, PartialEq)]
pub struct IntentToken {
    pub asset_id: String,
    pub symbol: String,
    pub decimals: u32,
    pub blockchain: String,
}

/// Terminal states included: poll until `Success`, `Refunded`, or `Failed`.
/// Byte-identical to the upstream `Status` renames.
#[derive(uniffi::Enum, Debug, PartialEq)]
pub enum IntentStatus {
    PendingDeposit,
    KnownDepositTx,
    IncompleteDeposit,
    Processing,
    Success,
    Refunded,
    Failed,
}

/// Quote parameters. `dry = true` previews without a deposit address;
/// `dry = false` reserves one (≈10 min validity).
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
}

#[derive(uniffi::Record, Debug)]
pub struct IntentQuote {
    pub deposit_address: Option<String>,
    pub amount_in: String,
    pub amount_out: String,
    pub min_amount_out: String,
    pub deadline: Option<String>,
    pub time_estimate_secs: f64,
}

#[derive(uniffi::Record, Debug)]
pub struct IntentStatusReport {
    pub status: IntentStatus,
    pub updated_at: String,
}

/// Blocking 1Click client. One method per call the box needs — nothing
/// else crosses the FFI.
#[derive(uniffi::Object)]
pub struct NearIntents {
    client: reqwest::blocking::Client,
    base_url: String,
    api_key: String,
}

fn parse_swap_type(value: &str) -> Result<SdkSwapType, CoreError> {
    match value {
        "EXACT_INPUT" => Ok(SdkSwapType::ExactInput),
        "EXACT_OUTPUT" => Ok(SdkSwapType::ExactOutput),
        _ => Err(CoreError::InvalidInput(format!(
            "swap type must be EXACT_INPUT or EXACT_OUTPUT, got {value}"
        ))),
    }
}

fn parse_deposit_type(value: &str) -> Result<SdkDepositType, CoreError> {
    match value {
        "ORIGIN_CHAIN" => Ok(SdkDepositType::OriginChain),
        "INTENTS" => Ok(SdkDepositType::Intents),
        _ => Err(CoreError::InvalidInput(format!(
            "deposit type must be ORIGIN_CHAIN or INTENTS, got {value}"
        ))),
    }
}

fn parse_refund_type(value: &str) -> Result<SdkRefundType, CoreError> {
    match value {
        "ORIGIN_CHAIN" => Ok(SdkRefundType::OriginChain),
        "INTENTS" => Ok(SdkRefundType::Intents),
        _ => Err(CoreError::InvalidInput(format!(
            "refund type must be ORIGIN_CHAIN or INTENTS, got {value}"
        ))),
    }
}

fn parse_recipient_type(value: &str) -> Result<SdkRecipientType, CoreError> {
    match value {
        "DESTINATION_CHAIN" => Ok(SdkRecipientType::DestinationChain),
        "INTENTS" => Ok(SdkRecipientType::Intents),
        _ => Err(CoreError::InvalidInput(format!(
            "recipient type must be DESTINATION_CHAIN or INTENTS, got {value}"
        ))),
    }
}

fn parse_status(value: &SdkStatus) -> IntentStatus {
    match value {
        SdkStatus::PendingDeposit => IntentStatus::PendingDeposit,
        SdkStatus::KnownDepositTx => IntentStatus::KnownDepositTx,
        SdkStatus::IncompleteDeposit => IntentStatus::IncompleteDeposit,
        SdkStatus::Processing => IntentStatus::Processing,
        SdkStatus::Success => IntentStatus::Success,
        SdkStatus::Refunded => IntentStatus::Refunded,
        SdkStatus::Failed => IntentStatus::Failed,
    }
}

fn parse_submit_status(value: &SdkSubmitStatus) -> IntentStatus {
    match value {
        SdkSubmitStatus::PendingDeposit => IntentStatus::PendingDeposit,
        SdkSubmitStatus::KnownDepositTx => IntentStatus::KnownDepositTx,
        SdkSubmitStatus::IncompleteDeposit => IntentStatus::IncompleteDeposit,
        SdkSubmitStatus::Processing => IntentStatus::Processing,
        SdkSubmitStatus::Success => IntentStatus::Success,
        SdkSubmitStatus::Refunded => IntentStatus::Refunded,
        SdkSubmitStatus::Failed => IntentStatus::Failed,
    }
}

impl NearIntents {
    fn get(
        &self,
        path: &str,
        authed: bool,
    ) -> Result<reqwest::blocking::RequestBuilder, CoreError> {
        let url = format!("{}{}", self.base_url, path);
        let mut req = self.client.get(url);
        if authed {
            req = req.header("X-API-Key", &self.api_key);
        }
        Ok(req)
    }

    fn post<T: serde::Serialize + ?Sized>(
        &self,
        path: &str,
        body: &T,
    ) -> Result<reqwest::blocking::RequestBuilder, CoreError> {
        let url = format!("{}{}", self.base_url, path);
        Ok(self
            .client
            .post(url)
            .header("X-API-Key", &self.api_key)
            .json(body))
    }

    fn read<T: serde::de::DeserializeOwned>(
        response: reqwest::blocking::Response,
        what: &str,
    ) -> Result<T, CoreError> {
        let status = response.status();
        let text = response
            .text()
            .map_err(|e| CoreError::Transport(format!("intents {what} unreadable: {e}")))?;
        if !status.is_success() {
            return Err(CoreError::Chain {
                code: format!("intents_http_{}", status.as_u16()),
                detail: text.chars().take(300).collect(),
            });
        }
        serde_json::from_str(&text)
            .map_err(|e| CoreError::Transport(format!("intents {what} malformed: {e}")))
    }
}

#[uniffi::export]
impl NearIntents {
    #[uniffi::constructor]
    pub fn new(base_url: String, api_key: String) -> Result<Self, CoreError> {
        if !(base_url.starts_with("http://") || base_url.starts_with("https://")) {
            return Err(CoreError::InvalidInput("intents url must be http(s)".into()));
        }
        if api_key.is_empty() {
            return Err(CoreError::InvalidInput(
                "intents api key must not be empty".into(),
            ));
        }
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|e| CoreError::Crypto(format!("http client failed: {e}")))?;
        Ok(Self {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            api_key,
        })
    }

    /// Swappable assets. Unauthenticated upstream; the key stays home.
    pub fn tokens(&self) -> Result<Vec<IntentToken>, CoreError> {
        let response = self
            .get("/v0/tokens", false)?
            .send()
            .map_err(|e| CoreError::Transport(format!("intents unreachable: {e}")))?;
        let tokens: Vec<one_click_sdk_rs::models::TokenResponse> =
            Self::read(response, "tokens")?;
        tokens
            .into_iter()
            .map(|t| {
                let blockchain = serde_json::to_value(&t.blockchain)
                    .ok()
                    .and_then(|v| v.as_str().map(String::from))
                    .unwrap_or_default();
                Ok(IntentToken {
                    asset_id: t.asset_id,
                    symbol: t.symbol,
                    decimals: t.decimals as u32,
                    blockchain,
                })
            })
            .collect::<Result<Vec<_>, CoreError>>()
    }

    /// Price a swap. `dry = true` previews; `false` reserves a deposit
    /// address the user must fund before the deadline.
    pub fn quote(&self, req: IntentQuoteRequest) -> Result<IntentQuote, CoreError> {
        let body = SdkQuoteRequest {
            dry: req.dry,
            swap_type: parse_swap_type(&req.swap_type)?,
            slippage_tolerance: req.slippage_bps as f64,
            origin_asset: req.origin_asset,
            deposit_type: parse_deposit_type(&req.deposit_type)?,
            destination_asset: req.destination_asset,
            amount: req.amount,
            refund_to: req.refund_to,
            refund_type: parse_refund_type(&req.refund_type)?,
            recipient: req.recipient,
            recipient_type: parse_recipient_type(&req.recipient_type)?,
            deadline: req.deadline,
            referral: None,
            quote_waiting_time_ms: None,
            app_fees: None,
        };
        let response = self
            .post("/v0/quote", &body)?
            .send()
            .map_err(|e| CoreError::Transport(format!("intents unreachable: {e}")))?;
        let quote: one_click_sdk_rs::models::QuoteResponse = Self::read(response, "quote")?;
        Ok(IntentQuote {
            deposit_address: quote.quote.deposit_address,
            amount_in: quote.quote.amount_in,
            amount_out: quote.quote.amount_out,
            min_amount_out: quote.quote.min_amount_out,
            deadline: quote.quote.deadline,
            time_estimate_secs: quote.quote.time_estimate.unwrap_or(0.0),
        })
    }

    /// Notify 1Click after funding the deposit address, to speed up
    /// detection. Returns the current execution state.
    pub fn submit_deposit(
        &self,
        deposit_address: String,
        tx_hash: String,
    ) -> Result<IntentStatusReport, CoreError> {
        let body = SdkSubmitRequest {
            tx_hash,
            deposit_address,
        };
        let response = self
            .post("/v0/deposit/submit", &body)?
            .send()
            .map_err(|e| CoreError::Transport(format!("intents unreachable: {e}")))?;
        let receipt: one_click_sdk_rs::models::SubmitDepositTxResponse =
            Self::read(response, "deposit submit")?;
        Ok(IntentStatusReport {
            status: parse_submit_status(&receipt.status),
            updated_at: receipt.updated_at,
        })
    }

    /// Poll until terminal: `Success`, `Refunded`, or `Failed`.
    pub fn status(&self, deposit_address: String) -> Result<IntentStatusReport, CoreError> {
        let response = self
            .get("/v0/status", true)?
            .query(&[("depositAddress", deposit_address)])
            .send()
            .map_err(|e| CoreError::Transport(format!("intents unreachable: {e}")))?;
        let report: one_click_sdk_rs::models::GetExecutionStatusResponse =
            Self::read(response, "status")?;
        Ok(IntentStatusReport {
            status: parse_status(&report.status),
            updated_at: report.updated_at,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;

    struct Mock {
        base_url: String,
        handle: thread::JoinHandle<(bool, bool)>,
        expect_auth: bool,
    }

    /// One-shot mock 1Click server: replays `reply`, records whether the
    /// request line matched and whether `X-API-Key` was attached.
    fn mock_server(expected_request_line: &str, reply: &str) -> (String, thread::JoinHandle<(bool, bool)>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("mock binds");
        let addr = listener.local_addr().expect("mock addr");
        let expected = expected_request_line.to_string();
        let body = reply.to_string();
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("mock accept");
            let mut buf = vec![0u8; 16384];
            let n = stream.read(&mut buf).expect("mock read");
            let head = String::from_utf8_lossy(&buf[..n]).into_owned();
            let response = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            );
            stream.write_all(response.as_bytes()).expect("mock write");
            (
                head.starts_with(&expected),
                head.to_lowercase().contains("x-api-key: secret"),
            )
        });
        (format!("http://{addr}"), handle)
    }

    fn check_mock(mock: Mock) {
        let (matched, authed) = mock.handle.join().expect("mock ran");
        assert!(matched, "mock saw an unexpected request line");
        assert_eq!(authed, mock.expect_auth, "X-API-Key presence mismatch");
    }

    fn wired(base: (String, thread::JoinHandle<(bool, bool)>), expect_auth: bool) -> (NearIntents, Mock) {
        let (base_url, handle) = base;
        let client = NearIntents::new(base_url.clone(), "secret".into()).expect("mock client");
        (
            client,
            Mock {
                base_url,
                handle,
                expect_auth,
            },
        )
    }

    const QUOTE_REQ: &str = r#""dry":false,"swapType":"EXACT_INPUT","slippageTolerance":100.0,"originAsset":"a","depositType":"ORIGIN_CHAIN","destinationAsset":"b","amount":"1","refundTo":"r","refundType":"ORIGIN_CHAIN","recipient":"r","recipientType":"DESTINATION_CHAIN","deadline":"d","referral":null,"quoteWaitingTimeMs":null,"appFees":null"#;

    fn quote_response(addr: Option<&str>) -> String {
        format!(
            r#"{{"timestamp":"t","signature":"s","quoteRequest":{{{}}},"quote":{{"depositAddress":{},"amountIn":"1","amountInFormatted":"1","amountInUsd":"0","minAmountIn":"1","amountOut":"2","amountOutFormatted":"2","amountOutUsd":"0","minAmountOut":"2","deadline":null,"timeWhenInactive":null,"timeEstimate":12.5}}}}"#,
            QUOTE_REQ,
            addr.map(|a| format!("\"{a}\"")).unwrap_or("null".into()),
        )
    }

    fn status_envelope(status: &str, updated: &str) -> String {
        format!(
            r#"{{"quoteResponse":{},"status":"{}","updatedAt":"{}","swapDetails":{{"intentHashes":[],"nearTxHashes":[],"originChainTxHashes":[],"destinationChainTxHashes":[]}}}}"#,
            quote_response(Some("dep-addr")),
            status,
            updated,
        )
    }

    fn intent_request() -> IntentQuoteRequest {
        IntentQuoteRequest {
            dry: false,
            swap_type: "EXACT_INPUT".into(),
            slippage_bps: 100,
            origin_asset: "a".into(),
            deposit_type: "ORIGIN_CHAIN".into(),
            destination_asset: "b".into(),
            amount: "1".into(),
            refund_to: "r".into(),
            refund_type: "ORIGIN_CHAIN".into(),
            recipient: "r".into(),
            recipient_type: "DESTINATION_CHAIN".into(),
            deadline: "d".into(),
        }
    }

    #[test]
    fn tokens_map_without_auth() {
        let server = mock_server(
            "GET /v0/tokens",
            r#"[{"assetId":"nep141:wrap.near","decimals":24.0,"blockchain":"near","symbol":"wNEAR","price":3.1,"priceUpdatedAt":"t"}]"#,
        );
        let (client, mock) = wired(server, false);
        let tokens = client.tokens().expect("tokens");
        check_mock(mock);
        assert_eq!(tokens.len(), 1);
        assert_eq!(tokens[0].asset_id, "nep141:wrap.near");
        assert_eq!(tokens[0].decimals, 24);
        assert_eq!(tokens[0].blockchain, "near");
    }

    #[test]
    fn wet_quote_reserves_address_with_key() {
        let server = mock_server("POST /v0/quote", &quote_response(Some("dep-addr")));
        let (client, mock) = wired(server, true);
        let quote = client.quote(intent_request()).expect("quote");
        check_mock(mock);
        assert_eq!(quote.deposit_address.as_deref(), Some("dep-addr"));
        assert_eq!(quote.amount_out, "2");
        assert_eq!(quote.time_estimate_secs, 12.5);
    }

    #[test]
    fn dry_quote_carries_no_address() {
        let server = mock_server("POST /v0/quote", &quote_response(None));
        let (client, mock) = wired(server, true);
        let mut req = intent_request();
        req.dry = true;
        let quote = client.quote(req).expect("quote");
        check_mock(mock);
        assert_eq!(quote.deposit_address, None);
    }

    #[test]
    fn unknown_swap_type_fails_before_network() {
        let client =
            NearIntents::new("http://127.0.0.1:1".into(), "secret".into()).expect("client");
        let mut req = intent_request();
        req.swap_type = "SOMETIMES".into();
        let err = client.quote(req).expect_err("bad swap type must fail");
        assert!(matches!(err, CoreError::InvalidInput(_)));
    }

    #[test]
    fn submit_and_status_round_trip() {
        let server = mock_server(
            "POST /v0/deposit/submit",
            &status_envelope("KNOWN_DEPOSIT_TX", "t"),
        );
        let (client, mock) = wired(server, true);
        let report = client
            .submit_deposit("dep-addr".into(), "0xhash".into())
            .expect("submit");
        check_mock(mock);
        assert_eq!(report.status, IntentStatus::KnownDepositTx);

        let server = mock_server("GET /v0/status", &status_envelope("SUCCESS", "t2"));
        let (client, mock) = wired(server, true);
        let report = client.status("dep-addr".into()).expect("status");
        check_mock(mock);
        assert_eq!(report.status, IntentStatus::Success);
        assert_eq!(report.updated_at, "t2");
    }

    #[test]
    fn http_error_maps_to_chain_code() {
        let listener = TcpListener::bind("127.0.0.1:0").expect("mock binds");
        let addr = listener.local_addr().expect("mock addr");
        thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("mock accept");
            let mut buf = vec![0u8; 4096];
            let _ = stream.read(&mut buf);
            let body = r#"{"message":"bad key"}"#;
            let response = format!(
                "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            );
            stream.write_all(response.as_bytes()).expect("mock write");
        });
        let client =
            NearIntents::new(format!("http://{addr}"), "secret".into()).expect("client");
        let err = client.tokens().expect_err("401 must fail");
        assert!(matches!(
            err,
            CoreError::Chain { code, .. } if code == "intents_http_401"
        ));
    }
}
