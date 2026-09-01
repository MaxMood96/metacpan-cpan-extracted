-- Deploy authzdemo:docs to sqlite
--
-- owner_id is the column every rule in lib/AuthzDemo/Authorisation.pm asks
-- about, and `public` is the one that decides whether a refusal has to be a
-- 404: a document nobody may see must not be confirmed to exist.

BEGIN;

CREATE TABLE docs (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    title    TEXT    NOT NULL,
    owner_id INTEGER NOT NULL,
    public   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX docs_owner ON docs (owner_id);

COMMIT;
