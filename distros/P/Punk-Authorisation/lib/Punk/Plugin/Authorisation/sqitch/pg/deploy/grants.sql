-- Deploy punk_authz:grants to pg
-- The unique index is what makes granting twice a no-op rather than two rows;
-- the second index is for "who may touch this object", which an admin page asks.

BEGIN;

CREATE TABLE authz_grants (
    id         bigserial PRIMARY KEY,
    subject_id bigint    NOT NULL,
    action     text      NOT NULL,
    object_id  text      NOT NULL,
    granted_by bigint,
    created    bigint
);
CREATE UNIQUE INDEX authz_grants_one ON authz_grants (subject_id, action, object_id);
CREATE INDEX authz_grants_object ON authz_grants (action, object_id);

COMMIT;
