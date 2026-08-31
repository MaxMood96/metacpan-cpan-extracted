-- Verify punk_passkey:passkeys on sqlite
-- Every column the ceremonies read or write, so a half-applied change
-- fails here rather than at the first login.

SELECT id, user_id, credential_id, public_key, sign_count,
       transports, aaguid, label, created_at, last_used_at
  FROM passkeys
 WHERE 0;
