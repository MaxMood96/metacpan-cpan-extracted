-- Verify punk_auth:users on sqlite

SELECT id, email, password_hash, verified
  FROM users
 WHERE 0;
