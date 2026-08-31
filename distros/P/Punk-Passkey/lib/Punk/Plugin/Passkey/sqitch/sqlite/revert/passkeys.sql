-- Revert punk_passkey:passkeys from sqlite

BEGIN;

DROP TABLE passkeys;

COMMIT;
