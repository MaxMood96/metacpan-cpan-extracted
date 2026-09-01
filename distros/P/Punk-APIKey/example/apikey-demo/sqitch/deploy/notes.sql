-- Deploy apikeydemo:notes to sqlite
-- requires: users

BEGIN;

-- What the API serves. `owner_id` is the account, which is what a key
-- identifies - so a key keeps reaching its account's notes after the person
-- who minted it is gone.
CREATE TABLE notes (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id INTEGER NOT NULL,
    body     TEXT    NOT NULL,
    created  INTEGER NOT NULL
);

CREATE INDEX notes_owner ON notes (owner_id);

COMMIT;
