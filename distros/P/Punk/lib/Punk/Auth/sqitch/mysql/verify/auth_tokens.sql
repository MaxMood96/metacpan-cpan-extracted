-- Verify punk_auth:auth_tokens on mysql

SELECT id, user_id, kind, digest, expires
  FROM auth_tokens
 WHERE 0;
