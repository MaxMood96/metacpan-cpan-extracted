-- Revert punk_authz:grants from pg

BEGIN;

DROP TABLE authz_grants;

COMMIT;
