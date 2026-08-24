-- Verify punk_auth:auth_tokens on sqlite

SELECT id, user_id, kind, digest, expires
  FROM auth_tokens
 WHERE 0;
