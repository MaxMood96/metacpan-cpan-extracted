-- Deploy punk_auth:auth_tokens to mysql
-- requires: users
-- Single-use tokens: only the SHA-256 digest is stored, with an absolute
-- expiry epoch. Single use is the delete plus the unique digest.

CREATE TABLE auth_tokens (
    id      BIGINT      PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT      NOT NULL,
    kind    VARCHAR(64) NOT NULL,
    digest  VARCHAR(64) NOT NULL,
    expires BIGINT      NOT NULL,
    UNIQUE KEY auth_tokens_digest (digest),
    CONSTRAINT auth_tokens_user FOREIGN KEY (user_id) REFERENCES users (id)
);
