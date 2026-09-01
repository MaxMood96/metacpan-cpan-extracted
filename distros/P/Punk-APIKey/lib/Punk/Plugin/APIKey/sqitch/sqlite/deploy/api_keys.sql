-- Deploy punk_apikey:api_keys to sqlite

BEGIN;

-- owner_id is a column, not a foreign key to any users table: a key
-- identifies an ACCOUNT, so it keeps working when the person who made it
-- leaves. It is also not this project's business what the application calls
-- its owners - and a plugin's Sqitch project cannot depend on the
-- application's own, which deploys last.
CREATE TABLE api_keys (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id     INTEGER NOT NULL,
    kind         TEXT    NOT NULL DEFAULT 'live',
    label        TEXT    NOT NULL,
    prefix       TEXT    NOT NULL,   -- kind prefix + 8 chars: recognisable, not usable
    digest       TEXT    NOT NULL,   -- sha256 hex of the whole key
    scopes       TEXT,               -- space separated
    rate_per_min INTEGER,
    expires      INTEGER,            -- epoch; null never expires
    revoked      INTEGER,            -- epoch; null is live
    last_used    INTEGER,
    created      INTEGER NOT NULL
);

-- The lookup every guarded request makes, and the reason it is one equality
-- test rather than a scan.
CREATE UNIQUE INDEX api_keys_digest ON api_keys (digest);

-- Listing an account's keys, which the account page does on every view.
CREATE INDEX api_keys_owner ON api_keys (owner_id);

COMMIT;
