-- Verify punk_auth:users on mysql

SELECT id, email, password_hash, verified
  FROM users
 WHERE 0;
