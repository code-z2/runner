use near_sdk::json_types::{Base64VecU8, U128};
use near_sdk::serde::Deserialize;
use near_sdk::store::LookupSet;
use near_sdk::{
    env, ext_contract, near, require, serde_json, AccountId, BorshStorageKey, CurveType, Gas, NearToken,
    PanicOnDefault, Promise, PromiseError, PromiseOrValue, PublicKey,
};

const GAS_FOR_ADD_PROPOSAL: Gas = Gas::from_tgas(20);
const GAS_FOR_APPROVE_STEP: Gas = Gas::from_tgas(95);
const GAS_FOR_ACT_PROPOSAL: Gas = Gas::from_tgas(70);
const GAS_FOR_RESOLVE: Gas = Gas::from_tgas(10);
const NANOS_PER_SECOND: u64 = 1_000_000_000;

#[near(serializers = [borsh])]
#[derive(BorshStorageKey)]
enum StorageKey {
    Merchants,
    UsedNonces,
}

#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Treasury {
    dao_id: AccountId,
    token_id: AccountId,
    attestor_public_key: [u8; 32],
    units_per_cent: u128,
    proposal_bond: u128,
    paused: bool,
    merchants: LookupSet<AccountId>,
    used_nonces: LookupSet<[u8; 32]>,
}

#[derive(Deserialize)]
#[serde(crate = "near_sdk::serde", deny_unknown_fields)]
struct ClaimPass {
    v: u8,
    account_id: AccountId,
    #[allow(dead_code)]
    activity_hash: String,
    max_amount_cents: u32,
    expires_at: u64,
    nonce: String,
}

#[near(serializers = [json])]
pub struct Config {
    pub dao_id: AccountId,
    pub token_id: AccountId,
    pub attestor_public_key: PublicKey,
    pub units_per_cent: U128,
    pub proposal_bond: U128,
    pub paused: bool,
}

#[near(serializers = [json])]
#[derive(Clone, Debug, PartialEq)]
pub enum ProposalKind {
    Transfer {
        token_id: String,
        receiver_id: AccountId,
        amount: U128,
        msg: Option<String>,
    },
}

#[near(serializers = [json])]
pub struct ProposalInput {
    pub description: String,
    pub kind: ProposalKind,
}

#[near(serializers = [json])]
pub enum Action {
    VoteApprove,
}

#[ext_contract(ext_dao)]
#[allow(dead_code)]
trait SputnikDao {
    fn add_proposal(&mut self, proposal: ProposalInput) -> u64;
    fn act_proposal(&mut self, id: u64, action: Action, proposal: ProposalKind, memo: Option<String>);
}

fn ed25519_key(public_key: &PublicKey) -> [u8; 32] {
    require!(public_key.curve_type() == CurveType::ED25519, "attestor key must be ed25519");
    public_key.as_bytes()[1..]
        .try_into()
        .unwrap_or_else(|_| env::panic_str("attestor key must be 32 bytes"))
}

fn parse_nonce(hex: &str) -> [u8; 32] {
    let bytes = hex.as_bytes();
    require!(bytes.len() == 64, "invalid nonce");
    let mut nonce = [0u8; 32];
    for (index, pair) in bytes.chunks(2).enumerate() {
        let text = core::str::from_utf8(pair).unwrap_or_else(|_| env::panic_str("invalid nonce"));
        nonce[index] = u8::from_str_radix(text, 16).unwrap_or_else(|_| env::panic_str("invalid nonce"));
    }
    nonce
}

#[near]
impl Treasury {
    #[init]
    pub fn new(
        dao_id: AccountId,
        token_id: AccountId,
        attestor_public_key: PublicKey,
        units_per_cent: U128,
        proposal_bond: U128,
    ) -> Self {
        require!(units_per_cent.0 > 0, "units_per_cent must be positive");
        Self {
            dao_id,
            token_id,
            attestor_public_key: ed25519_key(&attestor_public_key),
            units_per_cent: units_per_cent.0,
            proposal_bond: proposal_bond.0,
            paused: false,
            merchants: LookupSet::new(StorageKey::Merchants),
            used_nonces: LookupSet::new(StorageKey::UsedNonces),
        }
    }

    pub fn claim(
        &mut self,
        attestation: String,
        signature: Base64VecU8,
        merchant_id: AccountId,
        amount_cents: u32,
    ) -> Promise {
        require!(!self.paused, "treasury is paused");
        let signature: [u8; 64] = signature
            .0
            .try_into()
            .unwrap_or_else(|_| env::panic_str("invalid attestor signature"));
        require!(
            env::ed25519_verify(&signature, attestation.as_bytes(), &self.attestor_public_key),
            "invalid attestor signature"
        );
        let pass: ClaimPass =
            serde_json::from_str(&attestation).unwrap_or_else(|_| env::panic_str("invalid attestation"));
        require!(pass.v == 1, "unsupported attestation version");
        require!(pass.account_id == env::predecessor_account_id(), "attestation belongs to another account");
        require!(env::block_timestamp() / NANOS_PER_SECOND < pass.expires_at, "attestation expired");
        require!(self.merchants.contains(&merchant_id), "unknown merchant");
        require!(
            amount_cents > 0 && amount_cents <= pass.max_amount_cents,
            "amount must be between 1 cent and the attested maximum"
        );
        let nonce = parse_nonce(&pass.nonce);
        require!(self.used_nonces.insert(nonce), "attestation already used");
        let amount = u128::from(amount_cents)
            .checked_mul(self.units_per_cent)
            .unwrap_or_else(|| env::panic_str("amount overflow"));

        let kind = ProposalKind::Transfer {
            token_id: self.token_id.to_string(),
            receiver_id: merchant_id,
            amount: U128(amount),
            msg: None,
        };
        ext_dao::ext(self.dao_id.clone())
            .with_attached_deposit(NearToken::from_yoctonear(self.proposal_bond))
            .with_static_gas(GAS_FOR_ADD_PROPOSAL)
            .add_proposal(ProposalInput {
                description: format!("runner claim {}", pass.nonce),
                kind: kind.clone(),
            })
            .then(
                Self::ext(env::current_account_id())
                    .with_static_gas(GAS_FOR_APPROVE_STEP)
                    .on_proposal_added(pass.nonce, kind),
            )
    }

    #[private]
    pub fn on_proposal_added(
        &mut self,
        nonce: String,
        kind: ProposalKind,
        #[callback_result] proposal_id: Result<u64, PromiseError>,
    ) -> PromiseOrValue<bool> {
        match proposal_id {
            Err(_) => {
                self.used_nonces.remove(&parse_nonce(&nonce));
                env::log_str(&format!("claim {nonce} released: the DAO did not accept the payout proposal"));
                PromiseOrValue::Value(false)
            }
            Ok(id) => PromiseOrValue::Promise(
                ext_dao::ext(self.dao_id.clone())
                    .with_static_gas(GAS_FOR_ACT_PROPOSAL)
                    .act_proposal(id, Action::VoteApprove, kind, None)
                    .then(
                        Self::ext(env::current_account_id())
                            .with_static_gas(GAS_FOR_RESOLVE)
                            .on_proposal_approved(nonce, id),
                    ),
            ),
        }
    }

    #[private]
    pub fn on_proposal_approved(
        &mut self,
        nonce: String,
        proposal_id: u64,
        #[callback_result] result: Result<(), PromiseError>,
    ) -> bool {
        match result {
            Ok(()) => {
                env::log_str(&format!("claim {nonce} approved as DAO proposal {proposal_id}"));
                true
            }
            Err(_) => {
                env::log_str(&format!(
                    "claim {nonce} is DAO proposal {proposal_id} but was not approved; the council must approve or reject it"
                ));
                false
            }
        }
    }

    pub fn add_merchant(&mut self, account_id: AccountId) {
        self.assert_dao();
        self.merchants.insert(account_id);
    }

    pub fn remove_merchant(&mut self, account_id: AccountId) {
        self.assert_dao();
        self.merchants.remove(&account_id);
    }

    pub fn set_attestor(&mut self, public_key: PublicKey) {
        self.assert_dao();
        self.attestor_public_key = ed25519_key(&public_key);
    }

    pub fn set_proposal_bond(&mut self, proposal_bond: U128) {
        self.assert_dao();
        self.proposal_bond = proposal_bond.0;
    }

    pub fn set_dao(&mut self, dao_id: AccountId) {
        self.assert_dao();
        self.dao_id = dao_id;
    }

    pub fn pause(&mut self) {
        self.assert_dao();
        self.paused = true;
    }

    pub fn unpause(&mut self) {
        self.assert_dao();
        self.paused = false;
    }

    pub fn is_merchant(&self, account_id: AccountId) -> bool {
        self.merchants.contains(&account_id)
    }

    pub fn is_nonce_used(&self, nonce: String) -> bool {
        self.used_nonces.contains(&parse_nonce(&nonce))
    }

    pub fn get_attestor(&self) -> PublicKey {
        let mut key = vec![0u8];
        key.extend_from_slice(&self.attestor_public_key);
        PublicKey::try_from(key).unwrap_or_else(|_| env::panic_str("stored attestor key is invalid"))
    }

    pub fn get_config(&self) -> Config {
        Config {
            dao_id: self.dao_id.clone(),
            token_id: self.token_id.clone(),
            attestor_public_key: self.get_attestor(),
            units_per_cent: U128(self.units_per_cent),
            proposal_bond: U128(self.proposal_bond),
            paused: self.paused,
        }
    }

    fn assert_dao(&self) {
        require!(env::predecessor_account_id() == self.dao_id, "only the DAO can do this");
    }
}

#[cfg(test)]
mod tests;
