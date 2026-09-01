-- Revert authzdemo:user_role from sqlite
-- SQLite learned DROP COLUMN in 3.35; older clients rebuild the table.

BEGIN;

ALTER TABLE users DROP COLUMN role;

COMMIT;
