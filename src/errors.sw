library errors;

pub enum AccessError {
    SenderCannotSetAccessControl: (),
    SenderNotAdmin: (),
    SenderNotOwner: (),
    SenderNotOwnerOrApproved: (),
}

pub enum InitError {
    AdminIsNone: (),
    CannotReinitialize: (),
}

pub enum InputError {
    AccountsAndIdsLengthMismatch: (),
    AmountsAndIdsLengthMismatch: (),
    AdminDoesNotExist: (),
    ApprovedDoesNotExist: (),
    NotEnoughBalance: (),
    NotEnoughTokensToMint: (),
    OwnerDoesNotExist: (),
    TokenDoesNotExist: (),
    TokenSupplyCannotBeZero: (),
}