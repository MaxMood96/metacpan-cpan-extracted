-- Deploy punk_auth:users to mysql
-- Punk::Auth's default users table. A null password_hash is meaningful: the
-- account exists (an invite, a federated sign-in) with no password set.
-- VARCHAR rather than TEXT because MySQL cannot put a unique index on TEXT
-- without a prefix length; the default collation compares case-insensitively,
-- which is what the lower(email) index does elsewhere.

CREATE TABLE users (
    id            BIGINT       PRIMARY KEY AUTO_INCREMENT,
    email         VARCHAR(255) NOT NULL,
    password_hash TEXT,
    verified      INTEGER      NOT NULL DEFAULT 0,
    UNIQUE KEY users_email (email)
);
