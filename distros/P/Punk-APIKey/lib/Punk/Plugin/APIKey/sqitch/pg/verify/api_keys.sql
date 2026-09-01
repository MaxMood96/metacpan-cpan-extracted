-- Verify punk_apikey:api_keys on pg

SELECT id, owner_id, kind, label, prefix, digest, scopes, rate_per_min,
       expires, revoked, last_used, created
  FROM api_keys WHERE FALSE;
