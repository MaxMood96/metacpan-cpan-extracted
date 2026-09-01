-- Revert punk_apikey:api_keys from sqlite

BEGIN;

DROP TABLE api_keys;

COMMIT;
