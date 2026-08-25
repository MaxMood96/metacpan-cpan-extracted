-- Verify punk_totp:totp on sqlite

SELECT totp_secret, totp_last_counter, totp_enabled, totp_failed,
       totp_failed_at
  FROM users
 WHERE 0;
