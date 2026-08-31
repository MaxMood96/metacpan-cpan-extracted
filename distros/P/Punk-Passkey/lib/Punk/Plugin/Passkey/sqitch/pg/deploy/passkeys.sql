-- Deploy punk_passkey:passkeys to pg
-- requires: punk_auth:users
--
-- See the sqlite script for why credential_id is unique across the
-- whole table and why public_key holds the COSE bytes verbatim.

BEGIN;

CREATE TABLE passkeys (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id TEXT        NOT NULL UNIQUE,
    public_key    BYTEA       NOT NULL,
    sign_count    BIGINT      NOT NULL DEFAULT 0,
    transports    TEXT,
    aaguid        TEXT,
    label         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at  TIMESTAMPTZ
);

CREATE INDEX passkeys_user_id_idx ON passkeys (user_id);

COMMIT;
