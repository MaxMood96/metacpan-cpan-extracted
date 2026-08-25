-- Deploy punk_totp:totp to mysql
-- requires: punk_auth:users
-- The failure count and the epoch of the failure that last moved it are here
-- rather than in the session because a session without a store is a signed
-- cookie, and a counter the client holds is a counter the client can rewind
-- to before its failures.

ALTER TABLE users
    ADD COLUMN totp_secret       TEXT,
    ADD COLUMN totp_last_counter BIGINT,
    ADD COLUMN totp_enabled      INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN totp_failed       INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN totp_failed_at    BIGINT;
