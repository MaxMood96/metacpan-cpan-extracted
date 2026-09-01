-- Revert authzdemo:docs from sqlite

BEGIN;

DROP TABLE docs;

COMMIT;
