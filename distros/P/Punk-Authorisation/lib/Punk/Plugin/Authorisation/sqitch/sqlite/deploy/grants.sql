-- Deploy punk_authz:grants to sqlite
-- The unique index is what makes granting twice a no-op rather than two rows;
-- the second index is for "who may touch this object", which an admin page asks.

BEGIN;

CREATE TABLE authz_grants (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL,
    action     TEXT    NOT NULL,
    object_id  TEXT    NOT NULL,
    granted_by INTEGER,
    created    INTEGER
);
CREATE UNIQUE INDEX authz_grants_one ON authz_grants (subject_id, action, object_id);
CREATE INDEX authz_grants_object ON authz_grants (action, object_id);

COMMIT;
