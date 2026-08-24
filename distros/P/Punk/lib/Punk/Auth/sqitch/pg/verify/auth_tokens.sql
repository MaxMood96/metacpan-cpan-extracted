-- Verify punk_auth:auth_tokens on pg

BEGIN;

SELECT id, user_id, kind, digest, expires
  FROM auth_tokens
 WHERE FALSE;

ROLLBACK;
