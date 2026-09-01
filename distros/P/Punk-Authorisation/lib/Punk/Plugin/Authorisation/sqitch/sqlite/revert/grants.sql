-- Revert punk_authz:grants from sqlite

BEGIN;

DROP INDEX IF EXISTS authz_grants_object;
DROP INDEX IF EXISTS authz_grants_one;
DROP TABLE authz_grants;

COMMIT;
