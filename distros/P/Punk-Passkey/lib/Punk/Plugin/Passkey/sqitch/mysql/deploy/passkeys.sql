-- Deploy punk_passkey:passkeys to mysql
-- requires: punk_auth:users
--
-- See the sqlite script for why credential_id is unique across the
-- whole table and why public_key holds the COSE bytes verbatim.
--
-- credential_id is VARCHAR(255) and not TEXT because MySQL cannot put a
-- unique index on an unbounded column. A base64url credential id at the
-- spec's 1023-byte ceiling would not fit - but no authenticator emits
-- one near it, and the ceremony refuses anything over the ceiling
-- before it can reach this table.

BEGIN;

CREATE TABLE passkeys (
    id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id       BIGINT       NOT NULL,
    credential_id VARCHAR(255) NOT NULL UNIQUE,
    public_key    BLOB         NOT NULL,
    sign_count    BIGINT       NOT NULL DEFAULT 0,
    transports    TEXT,
    aaguid        VARCHAR(64),
    label         VARCHAR(255),
    created_at    DATETIME     NOT NULL,
    last_used_at  DATETIME,
    KEY passkeys_user_id_idx (user_id),
    CONSTRAINT passkeys_user_fk FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

COMMIT;
