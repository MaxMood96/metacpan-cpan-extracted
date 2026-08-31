-- Revert punk_passkey:passkeys from mysql

BEGIN;

DROP TABLE passkeys;

COMMIT;
