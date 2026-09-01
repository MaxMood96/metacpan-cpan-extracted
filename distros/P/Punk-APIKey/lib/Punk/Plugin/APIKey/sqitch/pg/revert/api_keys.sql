-- Revert punk_apikey:api_keys from pg

BEGIN;

DROP TABLE api_keys;

COMMIT;
