use super::*;
use ed25519_dalek::{Signer, SigningKey};
use near_sdk::test_utils::{get_logs, VMContextBuilder};
use near_sdk::testing_env;

const NOW_S: u64 = 1_800_000_000;
const NONCE: &str = "0101010101010101010101010101010101010101010101010101010101010101";
const DAO: &str = "runner.sputnik-dao.near";
const BOND: u128 = 100_000_000_000_000_000_000_000;

fn attestor() -> SigningKey {
    SigningKey::from_bytes(&[7u8; 32])
}

fn key_of(signer: &SigningKey) -> PublicKey {
    let mut key = vec![0u8];
    key.extend_from_slice(signer.verifying_key().as_bytes());
    PublicKey::try_from(key).unwrap()
}

fn attestor_public_key() -> PublicKey {
    key_of(&attestor())
}

fn account(name: &str) -> AccountId {
    name.parse().unwrap()
}

fn set_caller(caller: &str) {
    testing_env!(VMContextBuilder::new()
        .current_account_id(account("treasury.runner.near"))
        .predecessor_account_id(account(caller))
        .block_timestamp(NOW_S * NANOS_PER_SECOND)
        .account_balance(NearToken::from_near(10))
        .build());
}

fn setup() -> Treasury {
    set_caller(DAO);
    let mut treasury = Treasury::new(
        account(DAO),
        account("usdc.near"),
        attestor_public_key(),
        U128(10_000),
        U128(BOND),
    );
    treasury.add_merchant(account("mamaput.near"));
    treasury
}

fn pass(account_id: &str, max_amount_cents: u32, expires_at: u64, nonce: &str) -> (String, Base64VecU8) {
    let attestation = format!(
        "{{\"v\":1,\"account_id\":\"{account_id}\",\"activity_hash\":\"{}\",\"max_amount_cents\":{max_amount_cents},\"expires_at\":{expires_at},\"nonce\":\"{nonce}\"}}",
        "ab".repeat(32)
    );
    let signature = attestor().sign(attestation.as_bytes()).to_bytes().to_vec();
    (attestation, Base64VecU8(signature))
}

fn valid_pass() -> (String, Base64VecU8) {
    pass("runner.near", 256, NOW_S + 7200, NONCE)
}

fn transfer(amount: u128) -> ProposalKind {
    ProposalKind::Transfer {
        token_id: "usdc.near".to_string(),
        receiver_id: account("mamaput.near"),
        amount: U128(amount),
        msg: None,
    }
}

#[test]
fn claim_marks_the_pass_used() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 150);
    assert!(treasury.is_nonce_used(NONCE.to_string()));
}

#[test]
#[should_panic(expected = "attestation already used")]
fn claim_rejects_a_second_use() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation.clone(), signature.clone(), account("mamaput.near"), 100);
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
#[should_panic(expected = "invalid attestor signature")]
fn claim_rejects_a_changed_attestation() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation.replace("256", "500"), signature, account("mamaput.near"), 400);
}

#[test]
#[should_panic(expected = "attestation belongs to another account")]
fn claim_rejects_someone_elses_pass() {
    let mut treasury = setup();
    set_caller("thief.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
#[should_panic(expected = "attestation expired")]
fn claim_rejects_an_expired_pass() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = pass("runner.near", 256, NOW_S, NONCE);
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
#[should_panic(expected = "unknown merchant")]
fn claim_rejects_unregistered_merchants() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("random.near"), 100);
}

#[test]
#[should_panic(expected = "amount must be between 1 cent and the attested maximum")]
fn claim_rejects_more_than_the_maximum() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 257);
}

#[test]
#[should_panic(expected = "amount must be between 1 cent and the attested maximum")]
fn claim_rejects_zero() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 0);
}

#[test]
#[should_panic(expected = "treasury is paused")]
fn claim_stops_while_paused() {
    let mut treasury = setup();
    treasury.pause();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
#[should_panic(expected = "invalid attestation")]
fn claim_rejects_extra_fields() {
    let mut treasury = setup();
    set_caller("runner.near");
    let attestation = format!(
        "{{\"v\":1,\"account_id\":\"runner.near\",\"activity_hash\":\"x\",\"max_amount_cents\":100,\"expires_at\":{},\"nonce\":\"{NONCE}\",\"bonus\":1}}",
        NOW_S + 7200
    );
    let signature = Base64VecU8(attestor().sign(attestation.as_bytes()).to_bytes().to_vec());
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
fn a_payout_proposal_matches_what_sputnik_expects() {
    let kind = transfer(1_500_000);
    let json = serde_json::to_value(&ProposalInput { description: "runner claim x".into(), kind }).unwrap();
    assert_eq!(
        json,
        serde_json::json!({
            "description": "runner claim x",
            "kind": { "Transfer": { "token_id": "usdc.near", "receiver_id": "mamaput.near", "amount": "1500000", "msg": null } }
        })
    );
    assert_eq!(serde_json::to_value(Action::VoteApprove).unwrap(), serde_json::json!("VoteApprove"));
}

#[test]
fn an_added_proposal_moves_on_to_approval() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 150);
    set_caller("treasury.runner.near");
    let next = treasury.on_proposal_added(NONCE.to_string(), transfer(1_500_000), Ok(7));
    assert!(matches!(next, PromiseOrValue::Promise(_)));
    assert!(treasury.is_nonce_used(NONCE.to_string()));
}

#[test]
fn a_proposal_the_dao_refuses_frees_the_pass_for_retry() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 150);
    set_caller("treasury.runner.near");
    let next = treasury.on_proposal_added(NONCE.to_string(), transfer(1_500_000), Err(PromiseError::Failed));
    assert!(matches!(next, PromiseOrValue::Value(false)));
    assert!(!treasury.is_nonce_used(NONCE.to_string()));
}

#[test]
fn an_approved_claim_keeps_the_pass_used() {
    let mut treasury = setup();
    set_caller("treasury.runner.near");
    assert!(treasury.on_proposal_approved(NONCE.to_string(), 7, Ok(())));
    assert!(get_logs()[0].contains("approved as DAO proposal 7"));
}

#[test]
fn an_unapproved_proposal_is_left_for_the_council_and_never_reissued() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 150);
    set_caller("treasury.runner.near");
    assert!(!treasury.on_proposal_approved(NONCE.to_string(), 7, Err(PromiseError::Failed)));
    assert!(treasury.is_nonce_used(NONCE.to_string()));
    assert!(get_logs()[0].contains("council must approve or reject"));
}

#[test]
#[should_panic(expected = "only the DAO can do this")]
fn only_the_dao_adds_merchants() {
    let mut treasury = setup();
    set_caller("runner.near");
    treasury.add_merchant(account("fake.near"));
}

#[test]
#[should_panic(expected = "only the DAO can do this")]
fn only_the_dao_changes_the_attestor() {
    let mut treasury = setup();
    set_caller("runner.near");
    treasury.set_attestor(key_of(&SigningKey::from_bytes(&[9u8; 32])));
}

#[test]
fn the_dao_manages_merchants_bond_and_attestor() {
    let mut treasury = setup();
    assert!(treasury.is_merchant(account("mamaput.near")));
    treasury.remove_merchant(account("mamaput.near"));
    assert!(!treasury.is_merchant(account("mamaput.near")));
    treasury.set_proposal_bond(U128(1));
    let rotated = key_of(&SigningKey::from_bytes(&[9u8; 32]));
    treasury.set_attestor(rotated.clone());
    set_caller("escrow.runner.near");
    assert_eq!(treasury.get_attestor(), rotated);
    assert_eq!(treasury.get_config().proposal_bond, U128(1));
}

#[test]
#[should_panic(expected = "invalid attestor signature")]
fn the_old_attestor_stops_working_after_rotation() {
    let mut treasury = setup();
    treasury.set_attestor(key_of(&SigningKey::from_bytes(&[9u8; 32])));
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
fn moving_to_a_new_dao_hands_over_control() {
    let mut treasury = setup();
    treasury.set_dao(account("new.sputnik-dao.near"));
    set_caller("new.sputnik-dao.near");
    treasury.add_merchant(account("bole.near"));
    assert!(treasury.is_merchant(account("bole.near")));
    assert_eq!(treasury.get_config().dao_id, account("new.sputnik-dao.near"));
}

#[test]
fn config_reports_the_dao_and_attestor() {
    let treasury = setup();
    let config = treasury.get_config();
    assert_eq!(config.dao_id, account(DAO));
    assert_eq!(config.attestor_public_key, attestor_public_key());
    assert_eq!(config.units_per_cent, U128(10_000));
    assert_eq!(config.proposal_bond, U128(BOND));
    assert!(!config.paused);
}
