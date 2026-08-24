-- Revert punk_auth:users from sqlite

BEGIN;

DROP INDEX IF EXISTS users_email;
DROP TABLE users;

COMMIT;
