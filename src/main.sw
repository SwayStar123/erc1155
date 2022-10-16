contract;

dep data_structures;
dep errors;
dep events;
dep interface;

use data_structures::TokenMetaData;
use errors::{AccessError, InitError, InputError};
use events::{AdminEvent, ApprovalEvent, BurnEvent, MintEvent, OperatorEvent, TransferEvent, BatchTransferEvent};
use interface::NFT;
use std::{
    chain::auth::msg_sender,
    logging::log,
    storage::StorageMap,
};

storage {
    initialized: bool = false,
    /// Determines if only the contract's `admin` is allowed to call the mint function.
    /// This is only set on the initalization of the contract.
    access_control: bool = false,
    /// Stores the user that is permitted to mint if `access_control` is set to true.
    /// Will store `None` if this contract does not have `access_control` set.
    /// Only the `admin` is allowed to change the `admin` of the contract.
    admin: Option<Identity> = Option::None,
    /// Stores the user which is approved to transfer a token based on it's unique identifier.
    /// In the case that no user is approved to transfer a token based on the token owner's behalf,
    /// `None` will be stored.
    /// Map(token_id => approved)
    approved: StorageMap<(Identity, u64), Option<Identity>> = StorageMap {},
    /// Used for O(1) lookup of the number of tokens owned by each user.
    /// This increments or decrements when minting, transfering ownership, and burning tokens.
    /// Map(Identity => balance)
    balances: StorageMap<(Identity, u64), u64> = StorageMap {},
    /// Stores the `TokenMetadata` for each token based on the token's unique identifier.
    /// Map(token_id => TokenMetadata)
    meta_data: StorageMap<u64, TokenMetaData> = StorageMap {},
    /// Maps a tuple of (owner, operator) identities and stores whether the operator is allowed to
    /// transfer ALL tokens on the owner's behalf.
    /// Map((owner, operator) => approved)
    operator_approval: StorageMap<(Identity, Identity), bool> = StorageMap {},
    /// The total number of tokens that ever have been minted.
    /// This is used to assign token identifiers when minting. This will only be incremented.
    tokens_minted: StorageMap<u64, u64> = StorageMap {},
}

impl NFT for Contract {
    #[storage(read)]
    fn admin() -> Identity {
        // TODO: Remove this and update function definition to include Option once
        // https://github.com/FuelLabs/fuels-rs/issues/415 is revolved
        let admin = storage.admin;
        require(admin.is_some(), InputError::AdminDoesNotExist);
        admin.unwrap()
    }

    #[storage(read, write)]
    fn approve(approved: Identity, token_id: u64) {
        // Ensure this is a valid token
        // TODO: Remove this and update function definition to include Option once
        // https://github.com/FuelLabs/fuels-rs/issues/415 is revolved
        let approved = Option::Some(approved);

        // Ensure that the sender is the owner of the token to be approved
        let sender = msg_sender().unwrap();

        // Set and store the `approved` `Identity`
        storage.approved.insert((sender, token_id), approved);

        log(ApprovalEvent {
            owner: sender,
            approved,
            token_id,
        });
    }

    #[storage(read)]
    fn approved(identity: Identity, token_id: u64) -> Identity {
        // TODO: This should be removed and update function definition to include Option once
        // https://github.com/FuelLabs/fuels-rs/issues/415 is revolved
        // storage.approved.get(token_id)
        let approved = storage.approved.get((identity, token_id));
        require(approved.is_some(), InputError::ApprovedDoesNotExist);
        approved.unwrap()
    }

    #[storage(read)]
    fn balance_of(owner: Identity, id: u64) -> u64 {
        storage.balances.get((owner, id))
    }

    #[storage(read)]
    fn balance_of_batch(owners: Vec<Identity>, ids: Vec<u64>) -> Vec<u64> {
        require(owners.len == ids.len, InputError::AccountsAndIdsLengthMismatch);

        let mut batch_balances = ~Vec::new();
        let count = 0;
        while count < owners.len {
            batch_balances.push(storage.balances.get((owners.get(count).unwrap(), ids.get(count).unwrap())));
        }

        batch_balances
    }

    #[storage(read, write)]
    fn burn(token_id: u64, amount: u64) {
        let supply = storage.tokens_minted.get(token_id);
        require(supply > 0, InputError::TokenDoesNotExist);

        // Ensure the sender owns the token that is provided
        let sender = msg_sender().unwrap();
        require(storage.balances.get((sender, token_id)) > amount, InputError::NotEnoughBalance);

        storage.balances.insert((sender, token_id), storage.balances.get((sender, token_id)) - amount);

        log(BurnEvent {
            owner: sender,
            token_id,
            amount,
        });
    }

    #[storage(read, write)]
    fn constructor(access_control: bool, admin: Identity) {
        // This function can only be called once so if the token supply is already set it has
        // already been called
        // TODO: Remove this and update function definition to include Option once
        // https://github.com/FuelLabs/fuels-rs/issues/415 is revolved
        let admin = Option::Some(admin);
        require(storage.initialized == false, InitError::CannotReinitialize);
        require((access_control && admin.is_some()) || (!access_control && admin.is_none()), InitError::AdminIsNone);

        storage.access_control = access_control;
        storage.admin = admin;
        storage.initialized = true;
    }

    #[storage(read)]
    fn is_approved_for_all(operator: Identity, owner: Identity) -> bool {
        storage.operator_approval.get((owner, operator))
    }

    #[storage(read, write)]
    fn mint(amount: u64, to: Identity, id: u64) {
        let tokens_minted = storage.tokens_minted.get(id);
        let total_mint = tokens_minted + amount;

        // Ensure that the sender is the admin if this is a controlled access mint
        let admin = storage.admin;
        require(!storage.access_control || (admin.is_some() && msg_sender().unwrap() == admin.unwrap()), AccessError::SenderNotAdmin);

        storage.balances.insert((to, id), storage.balances.get((to, id)) + amount);
        storage.tokens_minted.insert(id, total_mint);

        log(MintEvent {
            owner: to,
            token_id_start: tokens_minted,
            total_tokens: amount,
        });
    }

    #[storage(read)]
    fn meta_data(token_id: u64) -> TokenMetaData {
        storage.meta_data.get(token_id)
    }

    #[storage(read, write)]
    fn set_admin(admin: Identity) {
        // Ensure that the sender is the admin
        // TODO: Remove this and update function definition to include Option once
        // https://github.com/FuelLabs/fuels-rs/issues/415 is revolved
        let admin = Option::Some(admin);
        let current_admin = storage.admin;
        require(current_admin.is_some() && msg_sender().unwrap() == current_admin.unwrap(), AccessError::SenderCannotSetAccessControl);
        storage.admin = admin;

        log(AdminEvent { admin });
    }

    #[storage(read, write)]
    fn set_approval_for_all(approve: bool, operator: Identity) {
        // Store `approve` with the (sender, operator) tuple
        let sender = msg_sender().unwrap();
        storage.operator_approval.insert((sender, operator, ), approve);

        log(OperatorEvent {
            approve,
            owner: sender,
            operator,
        });
    }

    #[storage(read, write)]
    fn transfer_from(from: Identity, to: Identity, token_id: u64, amount: u64) {
        require(storage.balances.get((from, token_id)) >= amount, InputError::NotEnoughBalance);

        // Ensure that the sender is either:
        // 1. The owner of the token
        // 2. Approved for transfer of this `token_id`
        // 3. Has operator approval for the `from` identity and this token belongs to the `from` identity
        let sender = msg_sender().unwrap();
        let approved = storage.approved.get((from, token_id));
        require((approved.is_some() && (sender == approved.unwrap())) || from == sender || storage.operator_approval.get((from, sender)), AccessError::SenderNotOwnerOrApproved);

        storage.balances.insert((from, token_id), storage.balances.get((from, token_id)) - amount);
        storage.balances.insert((to, token_id), storage.balances.get((to, token_id)) + amount);

        log(TransferEvent {
            from,
            sender,
            to,
            token_id,
            amount,
        });
    }

    #[storage(read, write)]
    fn batch_transfer_from(from: Identity, to: Identity, token_ids: Vec<u64>, amounts: Vec<u64>) {
        require(token_ids.len == amounts.len, InputError::AmountsAndIdsLengthMismatch);
        let sender = msg_sender().unwrap();

        let count = 0;
        while count < token_ids.len {
            let amount = amounts.get(count).unwrap();
            let token_id = token_ids.get(count).unwrap();
            require(storage.balances.get((from, token_id)) >= amount, InputError::NotEnoughBalance);

            // Ensure that the sender is either:
            // 1. The owner of the token
            // 2. Approved for transfer of this `token_id`
            // 3. Has operator approval for the `from` identity and this token belongs to the `from` identity
        
            let approved = storage.approved.get((from, token_id));
            require((approved.is_some() && (sender == approved.unwrap())) || from == sender || storage.operator_approval.get((from, sender)), AccessError::SenderNotOwnerOrApproved);

            storage.balances.insert((from, token_id), storage.balances.get((from, token_id)) - amount);
            storage.balances.insert((to, token_id), storage.balances.get((to, token_id)) + amount);
        }

        log(BatchTransferEvent {
            from,
            sender,
            to,
            token_ids,
            amounts,
        });
    }
}