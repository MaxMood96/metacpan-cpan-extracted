-- Deploy punk_auth:users to sqlite
-- Punk::Auth's default users table. A null password_hash is meaningful: the
-- account exists (an invite, a federated sign-in) with no password set.

BEGIN;

CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT    NOT NULL,
    password_hash TEXT,
    verified      INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX users_email ON users (lower(email));

COMMIT;
