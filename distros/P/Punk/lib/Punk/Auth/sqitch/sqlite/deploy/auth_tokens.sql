-- Deploy punk_auth:auth_tokens to sqlite
-- requires: users
-- Single-use tokens: only the SHA-256 digest is stored, with an absolute
-- expiry epoch. Single use is the delete plus the unique digest.

BEGIN;

CREATE TABLE auth_tokens (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users (id),
    kind    TEXT    NOT NULL,
    digest  TEXT    NOT NULL,
    expires INTEGER NOT NULL
);
CREATE UNIQUE INDEX auth_tokens_digest ON auth_tokens (digest);

COMMIT;
