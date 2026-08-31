-- Revert punk_passkey:passkeys from pg

BEGIN;

DROP TABLE passkeys;

COMMIT;
