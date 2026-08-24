-- Revert punk_auth:users from pg

BEGIN;

DROP TABLE users;

COMMIT;
