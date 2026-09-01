-- Revert apikeydemo:users from sqlite

BEGIN;

DROP TABLE users;

COMMIT;
