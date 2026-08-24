-- Revert punk_auth:auth_tokens from sqlite

BEGIN;

DROP INDEX IF EXISTS auth_tokens_digest;
DROP TABLE auth_tokens;

COMMIT;
