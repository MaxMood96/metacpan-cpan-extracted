-- Deploy punk_totp:totp to pg
-- requires: punk_auth:users
-- The secret cannot be hashed (whoever reads it can mint codes); the last
-- accepted counter is the replay floor; enabled is flipped by the
-- application only after a first successful verification.
--
-- The failure count and the epoch of the failure that last moved it are here
-- rather than in the session because a session without a store is a signed
-- cookie, and a counter the client holds is a counter the client can rewind
-- to before its failures.

BEGIN;

ALTER TABLE users
    ADD COLUMN totp_secret       text,
    ADD COLUMN totp_last_counter bigint,
    ADD COLUMN totp_enabled      integer NOT NULL DEFAULT 0,
    ADD COLUMN totp_failed       integer NOT NULL DEFAULT 0,
    ADD COLUMN totp_failed_at    bigint;

COMMIT;
