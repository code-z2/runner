use super::*;
use ed25519_dalek::{Signer, SigningKey};
use near_sdk::test_utils::VMContextBuilder;
use near_sdk::testing_env;

const LOCKED_AT_S: u64 = 1_800_000_000;
const USDC: u128 = 1_000_000;

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

fn set_caller(caller: &str, at_s: u64, deposit: u128) {
    testing_env!(VMContextBuilder::new()
        .current_account_id(account("escrow.ije.near"))
        .predecessor_account_id(account(caller))
        .block_timestamp(at_s * NANOS_PER_SECOND)
        .attached_deposit(NearToken::from_yoctonear(deposit))
        .build());
}

fn setup() -> Escrow {
    set_caller("ije.sputnik-dao.near", LOCKED_AT_S, 0);
    Escrow::new(
        account("ije.sputnik-dao.near"),
        account("usdc.near"),
        account("treasury.ije.near"),
        account("ije.sputnik-dao.near"),
        U128(USDC),
    )
}

fn lock_10k_under_55(escrow: &mut Escrow, owner: &str, amount: u128) -> u64 {
    set_caller("usdc.near", LOCKED_AT_S, 0);
    let result = escrow.ft_on_transfer(
        account(owner),
        U128(amount),
        "{\"distance_m\":10000,\"max_seconds\":3300}".to_string(),
    );
    assert!(matches!(result, PromiseOrValue::Value(U128(0))));
    escrow.get_locks(account(owner))[0].id.0
}

fn proof(owner: &str, started_at: u64, distance_m: u32, active_seconds: u32) -> (String, Base64VecU8) {
    let text = format!(
        "{{\"v\":1,\"kind\":\"run\",\"account_id\":\"{owner}\",\"activity_hash\":\"{}\",\"started_at\":{started_at},\"ended_at\":{},\"distance_m\":{distance_m},\"active_seconds\":{active_seconds}}}",
        "ab".repeat(32),
        started_at + u64::from(active_seconds)
    );
    let signature = attestor().sign(text.as_bytes()).to_bytes().to_vec();
    (text, Base64VecU8(signature))
}

fn unlock_with_key(escrow: &mut Escrow, id: u64, text: String, signature: Base64VecU8, key: PublicKey) -> U128 {
    let owner = env::predecessor_account_id();
    let now = env::block_timestamp() / NANOS_PER_SECOND;
    let _ = escrow.unlock(U64(id), text.clone(), signature.clone());
    set_caller("escrow.ije.near", now, 0);
    escrow.on_unlock_attestor(U64(id), owner, text, signature, Ok(key))
}

fn unlock(escrow: &mut Escrow, id: u64, text: String, signature: Base64VecU8) -> U128 {
    unlock_with_key(escrow, id, text, signature, attestor_public_key())
}

#[test]
fn deposit_with_a_goal_creates_a_lock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    let lock = escrow.get_lock(U64(id)).unwrap();
    assert_eq!(lock.amount, U128(25 * USDC));
    assert_eq!(lock.goal, Goal { distance_m: 10_000, max_seconds: Some(3_300) });
}

#[test]
fn deposits_are_refunded_when_they_cannot_become_a_lock() {
    let mut escrow = setup();
    set_caller("usdc.near", LOCKED_AT_S, 0);
    let bad_goal = escrow.ft_on_transfer(account("runner.ije.near"), U128(25 * USDC), "{\"distance_m\":10}".to_string());
    assert!(matches!(bad_goal, PromiseOrValue::Value(U128(25_000_000))));
    let not_json = escrow.ft_on_transfer(account("runner.ije.near"), U128(25 * USDC), "hello".to_string());
    assert!(matches!(not_json, PromiseOrValue::Value(U128(25_000_000))));
    let too_small = escrow.ft_on_transfer(account("runner.ije.near"), U128(USDC / 2), "{\"distance_m\":5000}".to_string());
    assert!(matches!(too_small, PromiseOrValue::Value(U128(500_000))));
    set_caller("other-token.near", LOCKED_AT_S, 0);
    let wrong_token = escrow.ft_on_transfer(account("runner.ije.near"), U128(25 * USDC), "{\"distance_m\":5000}".to_string());
    assert!(matches!(wrong_token, PromiseOrValue::Value(U128(25_000_000))));
    assert!(escrow.get_locks(account("runner.ije.near")).is_empty());
}

#[test]
fn a_run_that_beats_the_goal_unlocks_into_the_escrow_balance() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_020, 3_250);
    assert_eq!(unlock(&mut escrow, id, text, signature), U128(25 * USDC));
    assert!(escrow.get_lock(U64(id)).is_none());
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(25 * USDC));
}

#[test]
fn a_longer_run_counts_by_its_average_pace() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 12_000, 3_960);
    unlock(&mut escrow, id, text, signature);
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(25 * USDC));
}

#[test]
#[should_panic(expected = "run does not meet the goal")]
fn a_slow_run_does_not_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_301);
    unlock(&mut escrow, id, text, signature);
}

#[test]
#[should_panic(expected = "run does not meet the goal")]
fn a_short_run_does_not_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 9_990, 2_000);
    unlock(&mut escrow, id, text, signature);
}

#[test]
#[should_panic(expected = "run started before the goal was locked")]
fn an_earlier_run_does_not_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S - 1, 10_000, 3_000);
    unlock(&mut escrow, id, text, signature);
}

#[test]
#[should_panic(expected = "run proof belongs to another account")]
fn someone_elses_run_does_not_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("friend.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    unlock(&mut escrow, id, text, signature);
}

#[test]
#[should_panic(expected = "invalid attestor signature")]
fn a_changed_proof_does_not_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 5_000, 1_500);
    unlock(&mut escrow, id, text.replace("5000", "10000"), signature);
}

#[test]
#[should_panic(expected = "invalid run proof")]
fn a_claim_pass_is_not_a_run_proof() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let pass = format!(
        "{{\"v\":1,\"account_id\":\"runner.ije.near\",\"activity_hash\":\"x\",\"max_amount_cents\":500,\"expires_at\":{},\"nonce\":\"{}\"}}",
        LOCKED_AT_S + 90_000,
        "01".repeat(32)
    );
    let signature = Base64VecU8(attestor().sign(pass.as_bytes()).to_bytes().to_vec());
    unlock(&mut escrow, id, pass, signature);
}

#[test]
#[should_panic(expected = "lock belongs to another account")]
fn only_the_owner_can_unlock() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("thief.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("thief.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    unlock(&mut escrow, id, text, signature);
}

#[test]
fn giving_up_returns_half_and_sends_half_to_the_pool() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC + 1);
    set_caller("runner.ije.near", LOCKED_AT_S + 60, 1);
    assert_eq!(escrow.give_up(U64(id)), U128(12_500_001));
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(12_500_001));
    assert!(escrow.get_lock(U64(id)).is_none());
}

#[test]
#[should_panic(expected = "Requires attached deposit of exactly 1 yoctoNEAR")]
fn giving_up_needs_a_confirmed_call() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 60, 0);
    escrow.give_up(U64(id));
}

#[test]
fn a_failed_pool_transfer_is_owed_and_can_be_retried() {
    let mut escrow = setup();
    set_caller("escrow.ije.near", LOCKED_AT_S, 0);
    assert!(!escrow.on_pool_resolved(U128(5 * USDC), Err(PromiseError::Failed)));
    assert_eq!(escrow.get_config().pool_owed, U128(5 * USDC));
    let _ = escrow.flush_pool();
    assert_eq!(escrow.get_config().pool_owed, U128(0));
}

#[test]
fn unlocked_money_can_be_withdrawn_and_is_restored_if_the_transfer_fails() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    unlock(&mut escrow, id, text, signature);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_500, 1);
    let _ = escrow.withdraw(U128(10 * USDC), None);
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(15 * USDC));
    set_caller("escrow.ije.near", LOCKED_AT_S + 86_500, 0);
    assert!(!escrow.on_withdraw_resolved(account("runner.ije.near"), U128(10 * USDC), Err(PromiseError::Failed)));
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(25 * USDC));
}

#[test]
#[should_panic(expected = "not enough unlocked balance")]
fn cannot_withdraw_more_than_the_balance() {
    let mut escrow = setup();
    set_caller("runner.ije.near", LOCKED_AT_S, 1);
    let _ = escrow.withdraw(U128(1), None);
}

#[test]
fn unlocked_money_can_be_locked_again() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    unlock(&mut escrow, id, text, signature);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_500, 1);
    let next = escrow.lock_from_balance(U128(20 * USDC), Goal { distance_m: 21_098, max_seconds: Some(7_200) });
    assert_eq!(escrow.get_balance(account("runner.ije.near")), U128(5 * USDC));
    assert_eq!(escrow.get_lock(next).unwrap().amount, U128(20 * USDC));
}

fn rotated() -> SigningKey {
    SigningKey::from_bytes(&[9u8; 32])
}

fn rotated_public_key() -> PublicKey {
    let mut key = vec![0u8];
    key.extend_from_slice(rotated().verifying_key().as_bytes());
    PublicKey::try_from(key).unwrap()
}

#[test]
fn unlocking_checks_the_key_the_treasury_holds_now() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, _) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    let signature = Base64VecU8(rotated().sign(text.as_bytes()).to_bytes().to_vec());
    assert_eq!(unlock_with_key(&mut escrow, id, text, signature, rotated_public_key()), U128(25 * USDC));
}

#[test]
#[should_panic(expected = "invalid attestor signature")]
fn the_old_attestor_stops_working_once_the_treasury_rotates() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    unlock_with_key(&mut escrow, id, text, signature, rotated_public_key());
}

#[test]
#[should_panic(expected = "could not read the attestor from the treasury")]
fn unlocking_fails_closed_when_the_treasury_cannot_answer() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    let _ = escrow.unlock(U64(id), text.clone(), signature.clone());
    set_caller("escrow.ije.near", LOCKED_AT_S + 86_400, 0);
    escrow.on_unlock_attestor(U64(id), account("runner.ije.near"), text, signature, Err(PromiseError::Failed));
}

#[test]
#[should_panic(expected = "lock not found")]
fn a_lock_given_up_while_unlocking_cannot_be_paid_twice() {
    let mut escrow = setup();
    let id = lock_10k_under_55(&mut escrow, "runner.ije.near", 25 * USDC);
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 0);
    let (text, signature) = proof("runner.ije.near", LOCKED_AT_S + 3_600, 10_000, 3_000);
    let _ = escrow.unlock(U64(id), text.clone(), signature.clone());
    set_caller("runner.ije.near", LOCKED_AT_S + 86_400, 1);
    escrow.give_up(U64(id));
    set_caller("escrow.ije.near", LOCKED_AT_S + 86_400, 0);
    escrow.on_unlock_attestor(U64(id), account("runner.ije.near"), text, signature, Ok(attestor_public_key()));
}

#[test]
fn config_reports_where_the_pool_share_goes() {
    let escrow = setup();
    let config = escrow.get_config();
    assert_eq!(config.treasury_id, account("treasury.ije.near"));
    assert_eq!(config.pool_id, account("ije.sputnik-dao.near"));
}
