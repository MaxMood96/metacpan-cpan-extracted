-- Revert authzdemo:demo_data from sqlite

BEGIN;

DELETE FROM docs  WHERE id IN (1, 2, 3);
DELETE FROM users WHERE id IN (1, 2, 3);

COMMIT;
