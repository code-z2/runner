use super::*;
use ed25519_dalek::{Signer, SigningKey};
use near_sdk::test_utils::VMContextBuilder;
use near_sdk::testing_env;

const NOW_S: u64 = 1_800_000_000;
const NONCE: &str = "0101010101010101010101010101010101010101010101010101010101010101";

fn attestor() -> SigningKey {
    SigningKey::from_bytes(&[7u8; 32])
}

fn attestor_public_key() -> PublicKey {
    let mut key = vec![0u8];
    key.extend_from_slice(attestor().verifying_key().as_bytes());
    PublicKey::try_from(key).unwrap()
}

fn account(name: &str) -> AccountId {
    name.parse().unwrap()
}

fn set_caller(caller: &str) {
    testing_env!(VMContextBuilder::new()
        .current_account_id(account("treasury.runner.near"))
        .predecessor_account_id(account(caller))
        .block_timestamp(NOW_S * NANOS_PER_SECOND)
        .build());
}

fn setup() -> Treasury {
    set_caller("dao.sputnik-dao.near");
    let mut treasury = Treasury::new(
        account("dao.sputnik-dao.near"),
        account("usdc.near"),
        attestor_public_key(),
        U128(10_000),
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
    let changed = attestation.replace("256", "500");
    let _ = treasury.claim(changed, signature, account("mamaput.near"), 400);
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
fn failed_transfer_frees_the_pass_for_retry() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
    set_caller("treasury.runner.near");
    assert!(!treasury.on_claim_resolved(NONCE.to_string(), Err(PromiseError::Failed)));
    assert!(!treasury.is_nonce_used(NONCE.to_string()));
}

#[test]
fn successful_transfer_keeps_the_pass_used() {
    let mut treasury = setup();
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
    set_caller("treasury.runner.near");
    assert!(treasury.on_claim_resolved(NONCE.to_string(), Ok(())));
    assert!(treasury.is_nonce_used(NONCE.to_string()));
}

#[test]
#[should_panic(expected = "only the owner can do this")]
fn only_the_owner_adds_merchants() {
    let mut treasury = setup();
    set_caller("runner.near");
    treasury.add_merchant(account("fake.near"));
}

#[test]
fn owner_manages_merchants() {
    let mut treasury = setup();
    assert!(treasury.is_merchant(account("mamaput.near")));
    treasury.remove_merchant(account("mamaput.near"));
    assert!(!treasury.is_merchant(account("mamaput.near")));
}

#[test]
#[should_panic(expected = "pause the treasury before recovering funds")]
fn recovery_needs_a_pause() {
    let mut treasury = setup();
    let _ = treasury.recover(U128(1));
}

#[test]
fn recovery_works_while_paused() {
    let mut treasury = setup();
    treasury.pause();
    let _ = treasury.recover(U128(1));
}

#[test]
fn keeps_donations_only_in_the_configured_token() {
    let mut treasury = setup();
    set_caller("usdc.near");
    let kept = treasury.ft_on_transfer(account("donor.near"), U128(5_000_000), String::new());
    assert!(matches!(kept, PromiseOrValue::Value(U128(0))));
    set_caller("other-token.near");
    let refunded = treasury.ft_on_transfer(account("donor.near"), U128(5_000_000), String::new());
    assert!(matches!(refunded, PromiseOrValue::Value(U128(5_000_000))));
}

#[test]
fn config_reports_the_attestor_key() {
    let treasury = setup();
    let config = treasury.get_config();
    assert_eq!(config.attestor_public_key, attestor_public_key());
    assert_eq!(config.units_per_cent, U128(10_000));
    assert!(!config.paused);
}

fn other_key() -> PublicKey {
    let mut key = vec![0u8];
    key.extend_from_slice(SigningKey::from_bytes(&[9u8; 32]).verifying_key().as_bytes());
    PublicKey::try_from(key).unwrap()
}

#[test]
fn the_dao_links_the_escrow() {
    let mut treasury = setup();
    treasury.set_escrow(account("escrow.runner.near"));
    assert_eq!(treasury.get_config().escrow_id, Some(account("escrow.runner.near")));
}

#[test]
#[should_panic(expected = "only the owner can do this")]
fn only_the_dao_links_the_escrow() {
    let mut treasury = setup();
    set_caller("runner.near");
    treasury.set_escrow(account("fake-escrow.near"));
}

#[test]
fn rotating_the_attestor_updates_the_treasury_and_reaches_the_escrow() {
    let mut treasury = setup();
    treasury.set_escrow(account("escrow.runner.near"));
    treasury.set_attestor(other_key());
    assert_eq!(treasury.get_config().attestor_public_key, other_key());
}

#[test]
#[should_panic(expected = "invalid attestor signature")]
fn the_old_attestor_stops_working_after_rotation() {
    let mut treasury = setup();
    treasury.set_attestor(other_key());
    set_caller("runner.near");
    let (attestation, signature) = valid_pass();
    let _ = treasury.claim(attestation, signature, account("mamaput.near"), 100);
}

#[test]
#[should_panic(expected = "no escrow is linked")]
fn syncing_needs_a_linked_escrow() {
    let mut treasury = setup();
    set_caller("anyone.near");
    let _ = treasury.sync_escrow_attestor();
}

#[test]
fn anyone_can_push_the_current_attestor_to_the_escrow() {
    let mut treasury = setup();
    treasury.set_escrow(account("escrow.runner.near"));
    set_caller("anyone.near");
    let _ = treasury.sync_escrow_attestor();
}

#[test]
fn a_failed_sync_is_reported() {
    let mut treasury = setup();
    set_caller("treasury.runner.near");
    assert!(!treasury.on_attestor_synced(Err(PromiseError::Failed)));
    assert!(treasury.on_attestor_synced(Ok(())));
}
