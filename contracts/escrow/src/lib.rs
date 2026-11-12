use near_sdk::json_types::{Base64VecU8, U128, U64};
use near_sdk::serde::Deserialize;
use near_sdk::store::LookupMap;
use near_sdk::{
    assert_one_yocto, env, ext_contract, near, require, serde_json, AccountId, BorshStorageKey, CurveType, Gas,
    NearToken, PanicOnDefault, Promise, PromiseError, PromiseOrValue, PublicKey,
};

const GAS_FOR_FT_TRANSFER: Gas = Gas::from_tgas(10);
const GAS_FOR_RESOLVE: Gas = Gas::from_tgas(10);
const GAS_FOR_ATTESTOR_VIEW: Gas = Gas::from_tgas(5);
const GAS_FOR_UNLOCK_RESOLVE: Gas = Gas::from_tgas(15);
const ONE_YOCTO: NearToken = NearToken::from_yoctonear(1);
const NANOS_PER_SECOND: u64 = 1_000_000_000;
const MIN_GOAL_DISTANCE_M: u32 = 1_000;
const MAX_GOAL_DISTANCE_M: u32 = 100_000;
const MIN_GOAL_SECONDS: u32 = 60;
const MAX_GOAL_SECONDS: u32 = 86_400;

#[near(serializers = [borsh])]
#[derive(BorshStorageKey)]
enum StorageKey {
    Locks,
    LocksByOwner,
    Balances,
}

#[near(serializers = [borsh, json])]
#[derive(Clone, Debug, PartialEq)]
pub struct Goal {
    pub distance_m: u32,
    pub max_seconds: Option<u32>,
}

/// Deposit message for `ft_on_transfer`. Naming another account as `owner`
/// locks the sender's own funds under that account's control, so it cannot
/// steal: the named owner can only unlock by running, or give up (half to the
/// pool). A bare `Goal` keeps the old meaning with `owner = sender`.
#[derive(Deserialize)]
#[serde(crate = "near_sdk::serde")]
struct DepositMsg {
    owner: AccountId,
    goal: Goal,
}

#[near(serializers = [borsh])]
pub struct Lock {
    owner_id: AccountId,
    amount: u128,
    goal: Goal,
    created_at: u64,
}

#[near(serializers = [json])]
pub struct LockView {
    pub id: U64,
    pub owner_id: AccountId,
    pub amount: U128,
    pub goal: Goal,
    pub created_at: U64,
}

#[near(serializers = [json])]
pub struct Config {
    pub owner_id: AccountId,
    pub token_id: AccountId,
    pub treasury_id: AccountId,
    pub pool_id: AccountId,
    pub min_lock: U128,
    pub skew_bps: u32,
    pub pool_owed: U128,
}

#[derive(Deserialize)]
#[serde(crate = "near_sdk::serde", deny_unknown_fields)]
struct RunProof {
    v: u8,
    kind: String,
    account_id: AccountId,
    #[allow(dead_code)]
    activity_hash: String,
    started_at: u64,
    #[allow(dead_code)]
    ended_at: u64,
    distance_m: u32,
    active_seconds: u32,
}

#[ext_contract(ext_treasury)]
#[allow(dead_code)]
trait Treasury {
    fn get_attestor(&self) -> PublicKey;
}

#[ext_contract(ext_ft)]
#[allow(dead_code)]
trait FungibleToken {
    fn ft_transfer(&mut self, receiver_id: AccountId, amount: U128, memo: Option<String>);
}

/// Default deposit skew tolerance: 500 bps (5%). Covers stablecoin intent
/// slippage with margin while keeping the `min_lock` dust floor meaningful.
const DEFAULT_SKEW_BPS: u32 = 500;
/// Hard cap on the skew tolerance: 5000 bps (50%). Beyond this the minimum
/// stops being a minimum.
const MAX_SKEW_BPS: u32 = 5_000;
const BPS_DENOMINATOR: u128 = 10_000;

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Escrow {
    owner_id: AccountId,
    token_id: AccountId,
    treasury_id: AccountId,
    pool_id: AccountId,
    min_lock: u128,
    skew_bps: u32,
    next_lock_id: u64,
    pool_owed: u128,
    locks: LookupMap<u64, Lock>,
    locks_by_owner: LookupMap<AccountId, Vec<u64>>,
    balances: LookupMap<AccountId, u128>,
}

fn ed25519_key(public_key: &PublicKey) -> [u8; 32] {
    require!(public_key.curve_type() == CurveType::ED25519, "attestor key must be ed25519");
    public_key.as_bytes()[1..]
        .try_into()
        .unwrap_or_else(|_| env::panic_str("attestor key must be 32 bytes"))
}

fn goal_is_valid(goal: &Goal) -> bool {
    (MIN_GOAL_DISTANCE_M..=MAX_GOAL_DISTANCE_M).contains(&goal.distance_m)
        && goal.max_seconds.map_or(true, |seconds| (MIN_GOAL_SECONDS..=MAX_GOAL_SECONDS).contains(&seconds))
}

fn goal_is_met(goal: &Goal, distance_m: u32, active_seconds: u32) -> bool {
    if distance_m < goal.distance_m {
        return false;
    }
    match goal.max_seconds {
        None => true,
        Some(max_seconds) => {
            u128::from(active_seconds) * u128::from(goal.distance_m) <= u128::from(max_seconds) * u128::from(distance_m)
        }
    }
}

#[near]
impl Escrow {
    #[init]
    pub fn new(
        owner_id: AccountId,
        token_id: AccountId,
        treasury_id: AccountId,
        pool_id: AccountId,
        min_lock: U128,
    ) -> Self {
        require!(min_lock.0 > 0, "min_lock must be positive");
        Self {
            owner_id,
            token_id,
            treasury_id,
            pool_id,
            min_lock: min_lock.0,
            skew_bps: DEFAULT_SKEW_BPS,
            next_lock_id: 0,
            pool_owed: 0,
            locks: LookupMap::new(StorageKey::Locks),
            locks_by_owner: LookupMap::new(StorageKey::LocksByOwner),
            balances: LookupMap::new(StorageKey::Balances),
        }
    }

    pub fn ft_on_transfer(&mut self, sender_id: AccountId, amount: U128, msg: String) -> PromiseOrValue<U128> {
        if env::predecessor_account_id() != self.token_id || !self.meets_minimum(amount.0) {
            return PromiseOrValue::Value(amount);
        }
        // Owner-attributed deposit (intent solvers delivering for a user)
        // first, bare Goal with owner = sender (relay path) second.
        let (owner_id, goal) = match serde_json::from_str::<DepositMsg>(&msg) {
            Ok(deposit) => (deposit.owner, deposit.goal),
            Err(_) => match serde_json::from_str::<Goal>(&msg) {
                Ok(goal) => (sender_id, goal),
                Err(_) => return PromiseOrValue::Value(amount),
            },
        };
        if !goal_is_valid(&goal) {
            return PromiseOrValue::Value(amount);
        }
        self.create_lock(owner_id, amount.0, goal);
        PromiseOrValue::Value(U128(0))
    }

    #[payable]
    pub fn lock_from_balance(&mut self, amount: U128, goal: Goal) -> U64 {
        assert_one_yocto();
        require!(self.meets_minimum(amount.0), "amount is below the minimum lock");
        require!(goal_is_valid(&goal), "invalid goal");
        let owner_id = env::predecessor_account_id();
        self.debit(&owner_id, amount.0);
        U64(self.create_lock(owner_id, amount.0, goal))
    }

    pub fn unlock(&mut self, lock_id: U64, proof: String, signature: Base64VecU8) -> Promise {
        let owner_id = env::predecessor_account_id();
        let lock = self.owned_lock(lock_id.0, &owner_id);
        require!(signature.0.len() == 64, "invalid attestor signature");
        let run: RunProof = serde_json::from_str(&proof).unwrap_or_else(|_| env::panic_str("invalid run proof"));
        require!(run.v == 1 && run.kind == "run", "unsupported run proof");
        require!(run.account_id == owner_id, "run proof belongs to another account");
        require!(
            u128::from(run.started_at) * u128::from(NANOS_PER_SECOND) >= u128::from(lock.created_at),
            "run started before the goal was locked"
        );
        require!(goal_is_met(&lock.goal, run.distance_m, run.active_seconds), "run does not meet the goal");
        ext_treasury::ext(self.treasury_id.clone())
            .with_static_gas(GAS_FOR_ATTESTOR_VIEW)
            .get_attestor()
            .then(
                Self::ext(env::current_account_id())
                    .with_static_gas(GAS_FOR_UNLOCK_RESOLVE)
                    .on_unlock_attestor(lock_id, owner_id, proof, signature),
            )
    }

    #[private]
    pub fn on_unlock_attestor(
        &mut self,
        lock_id: U64,
        owner_id: AccountId,
        proof: String,
        signature: Base64VecU8,
        #[callback_result] attestor: Result<PublicKey, PromiseError>,
    ) -> U128 {
        let attestor =
            attestor.unwrap_or_else(|_| env::panic_str("could not read the attestor from the treasury"));
        let signature: [u8; 64] = signature
            .0
            .try_into()
            .unwrap_or_else(|_| env::panic_str("invalid attestor signature"));
        require!(
            env::ed25519_verify(&signature, proof.as_bytes(), &ed25519_key(&attestor)),
            "invalid attestor signature"
        );
        let amount = self.owned_lock(lock_id.0, &owner_id).amount;
        self.remove_lock(lock_id.0, &owner_id);
        self.credit(&owner_id, amount);
        U128(amount)
    }

    #[payable]
    pub fn give_up(&mut self, lock_id: U64) -> U128 {
        assert_one_yocto();
        let owner_id = env::predecessor_account_id();
        let lock = self.owned_lock(lock_id.0, &owner_id);
        let pool_share = lock.amount / 2;
        let returned = lock.amount - pool_share;
        self.remove_lock(lock_id.0, &owner_id);
        self.credit(&owner_id, returned);
        if pool_share > 0 {
            self.send_to_pool(pool_share).detach();
        }
        U128(returned)
    }

    pub fn flush_pool(&mut self) -> Promise {
        require!(self.pool_owed > 0, "nothing owed to the pool");
        let amount = self.pool_owed;
        self.pool_owed = 0;
        self.send_to_pool(amount)
    }

    #[payable]
    pub fn withdraw(&mut self, amount: U128, receiver_id: Option<AccountId>) -> Promise {
        assert_one_yocto();
        require!(amount.0 > 0, "amount must be positive");
        let owner_id = env::predecessor_account_id();
        self.debit(&owner_id, amount.0);
        ext_ft::ext(self.token_id.clone())
            .with_attached_deposit(ONE_YOCTO)
            .with_static_gas(GAS_FOR_FT_TRANSFER)
            .ft_transfer(receiver_id.unwrap_or_else(|| owner_id.clone()), amount, None)
            .then(
                Self::ext(env::current_account_id())
                    .with_static_gas(GAS_FOR_RESOLVE)
                    .on_withdraw_resolved(owner_id, amount),
            )
    }

    #[private]
    pub fn on_withdraw_resolved(
        &mut self,
        owner_id: AccountId,
        amount: U128,
        #[callback_result] result: Result<(), PromiseError>,
    ) -> bool {
        if result.is_ok() {
            return true;
        }
        self.credit(&owner_id, amount.0);
        false
    }

    #[private]
    pub fn on_pool_resolved(&mut self, amount: U128, #[callback_result] result: Result<(), PromiseError>) -> bool {
        if result.is_ok() {
            return true;
        }
        self.pool_owed += amount.0;
        false
    }

    pub fn set_min_lock(&mut self, min_lock: U128) {
        self.assert_owner();
        require!(min_lock.0 > 0, "min_lock must be positive");
        self.min_lock = min_lock.0;
    }

    pub fn set_skew_bps(&mut self, skew_bps: u32) {
        self.assert_owner();
        require!(skew_bps <= MAX_SKEW_BPS, "skew_bps above maximum");
        self.skew_bps = skew_bps;
    }

    pub fn set_owner(&mut self, owner_id: AccountId) {
        self.assert_owner();
        self.owner_id = owner_id;
    }

    pub fn get_lock(&self, lock_id: U64) -> Option<LockView> {
        self.locks.get(&lock_id.0).map(|lock| Self::view(lock_id.0, lock))
    }

    pub fn get_locks(&self, account_id: AccountId) -> Vec<LockView> {
        self.locks_by_owner
            .get(&account_id)
            .map(|ids| {
                ids.iter()
                    .filter_map(|id| self.locks.get(id).map(|lock| Self::view(*id, lock)))
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn get_balance(&self, account_id: AccountId) -> U128 {
        U128(self.balances.get(&account_id).copied().unwrap_or(0))
    }

    pub fn get_config(&self) -> Config {
        Config {
            owner_id: self.owner_id.clone(),
            token_id: self.token_id.clone(),
            treasury_id: self.treasury_id.clone(),
            pool_id: self.pool_id.clone(),
            min_lock: U128(self.min_lock),
            skew_bps: self.skew_bps,
            pool_owed: U128(self.pool_owed),
        }
    }

    fn view(id: u64, lock: &Lock) -> LockView {
        LockView {
            id: U64(id),
            owner_id: lock.owner_id.clone(),
            amount: U128(lock.amount),
            goal: lock.goal.clone(),
            created_at: U64(lock.created_at),
        }
    }

    fn create_lock(&mut self, owner_id: AccountId, amount: u128, goal: Goal) -> u64 {
        let id = self.next_lock_id;
        self.next_lock_id += 1;
        self.locks.insert(
            id,
            Lock {
                owner_id: owner_id.clone(),
                amount,
                goal,
                created_at: env::block_timestamp(),
            },
        );
        self.locks_by_owner.entry(owner_id).or_default().push(id);
        id
    }

    /// Floor is `min_lock` less the skew tolerance, all integer math:
    /// `amount * 10_000 >= min_lock * (10_000 - skew_bps)`.
    fn meets_minimum(&self, amount: u128) -> bool {
        amount.saturating_mul(BPS_DENOMINATOR)
            >= self.min_lock.saturating_mul(BPS_DENOMINATOR - u128::from(self.skew_bps))
    }

    fn owned_lock(&self, lock_id: u64, owner_id: &AccountId) -> &Lock {
        let lock = self.locks.get(&lock_id).unwrap_or_else(|| env::panic_str("lock not found"));
        require!(&lock.owner_id == owner_id, "lock belongs to another account");
        lock
    }

    fn remove_lock(&mut self, lock_id: u64, owner_id: &AccountId) {
        self.locks.remove(&lock_id);
        if let Some(ids) = self.locks_by_owner.get_mut(owner_id) {
            ids.retain(|id| *id != lock_id);
            if ids.is_empty() {
                self.locks_by_owner.remove(owner_id);
            }
        }
    }

    fn credit(&mut self, owner_id: &AccountId, amount: u128) {
        let balance = self.balances.entry(owner_id.clone()).or_insert(0);
        *balance = balance.checked_add(amount).unwrap_or_else(|| env::panic_str("balance overflow"));
    }

    fn debit(&mut self, owner_id: &AccountId, amount: u128) {
        let balance = self.balances.get(owner_id).copied().unwrap_or(0);
        require!(balance >= amount, "not enough unlocked balance");
        if balance == amount {
            self.balances.remove(owner_id);
        } else {
            self.balances.insert(owner_id.clone(), balance - amount);
        }
    }

    fn send_to_pool(&mut self, amount: u128) -> Promise {
        ext_ft::ext(self.token_id.clone())
            .with_attached_deposit(ONE_YOCTO)
            .with_static_gas(GAS_FOR_FT_TRANSFER)
            .ft_transfer(self.pool_id.clone(), U128(amount), Some("goal given up".to_string()))
            .then(
                Self::ext(env::current_account_id())
                    .with_static_gas(GAS_FOR_RESOLVE)
                    .on_pool_resolved(U128(amount)),
            )
    }

    fn assert_owner(&self) {
        require!(env::predecessor_account_id() == self.owner_id, "only the owner can do this");
    }
}

#[cfg(test)]
mod tests;
