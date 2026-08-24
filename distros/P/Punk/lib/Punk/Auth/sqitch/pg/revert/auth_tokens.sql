-- Revert punk_auth:auth_tokens from pg

BEGIN;

DROP TABLE auth_tokens;

COMMIT;
