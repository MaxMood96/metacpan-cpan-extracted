-- Verify punk_auth:users on pg

BEGIN;

SELECT id, email, password_hash, verified
  FROM users
 WHERE FALSE;

ROLLBACK;
