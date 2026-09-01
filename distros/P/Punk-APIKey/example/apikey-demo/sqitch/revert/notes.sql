-- Revert apikeydemo:notes from sqlite

BEGIN;

DROP TABLE notes;

COMMIT;
