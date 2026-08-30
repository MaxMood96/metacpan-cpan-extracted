-- Revert punk-observe:alert_reason from sqlite
--
-- SQLite below 3.35 cannot drop a column; the column is nullable and
-- harmless, so revert leaves it in place rather than recreating the table
-- under live readers.

BEGIN;

COMMIT;
