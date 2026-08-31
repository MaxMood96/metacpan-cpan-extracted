-- Verify punk_passkey:passkeys on pg

SELECT id, user_id, credential_id, public_key, sign_count,
       transports, aaguid, label, created_at, last_used_at
  FROM passkeys
 WHERE FALSE;
