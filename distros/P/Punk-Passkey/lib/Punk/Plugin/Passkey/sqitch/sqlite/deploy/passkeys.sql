-- Deploy punk_passkey:passkeys to sqlite
-- requires: punk_auth:users
--
-- One row per credential, not per user: a passkey user is expected to
-- have several - a phone, a laptop, a hardware key - and the account
-- that cannot register a second one is the account that is lost with
-- the first device.
--
-- credential_id is UNIQUE across the whole table rather than per user.
-- The spec requires refusing a credential already registered to
-- somebody else, and a constraint does that without a check-then-insert
-- race; scoping it per user would let the same authenticator be
-- claimed twice and leave the login lookup ambiguous.
--
-- public_key holds the COSE key exactly as the authenticator sent it,
-- as bytes. Storing what arrived rather than a re-encoding means the
-- algorithm allowlist is applied again on every login, when the key is
-- re-imported, instead of being trusted because it passed once.

BEGIN;

CREATE TABLE passkeys (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id TEXT    NOT NULL UNIQUE,
    public_key    BLOB    NOT NULL,
    sign_count    INTEGER NOT NULL DEFAULT 0,
    transports    TEXT,
    aaguid        TEXT,
    label         TEXT,
    created_at    INTEGER NOT NULL,
    last_used_at  INTEGER
);

CREATE INDEX passkeys_user_id_idx ON passkeys (user_id);

COMMIT;
