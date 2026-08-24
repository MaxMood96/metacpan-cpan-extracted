-- Deploy punk_auth:auth_tokens to pg
-- requires: users
-- Single-use tokens: only the SHA-256 digest is stored, with an absolute
-- expiry epoch. Single use is the delete plus the unique digest.

BEGIN;

CREATE TABLE auth_tokens (
    id      bigserial PRIMARY KEY,
    user_id bigint    NOT NULL REFERENCES users (id),
    kind    text      NOT NULL,
    digest  text      NOT NULL,
    expires bigint    NOT NULL
);
CREATE UNIQUE INDEX auth_tokens_digest ON auth_tokens (digest);

COMMIT;
