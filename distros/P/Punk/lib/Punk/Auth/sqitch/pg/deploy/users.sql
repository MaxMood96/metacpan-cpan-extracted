-- Deploy punk_auth:users to pg
-- Punk::Auth's default users table. A null password_hash is meaningful: the
-- account exists (an invite, a federated sign-in) with no password set.

BEGIN;

CREATE TABLE users (
    id            bigserial PRIMARY KEY,
    email         text      NOT NULL,
    password_hash text,
    verified      integer   NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX users_email ON users (lower(email));

COMMIT;
