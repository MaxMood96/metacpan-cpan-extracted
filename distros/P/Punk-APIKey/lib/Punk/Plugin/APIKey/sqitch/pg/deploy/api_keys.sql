-- Deploy punk_apikey:api_keys to pg

BEGIN;

-- owner_id is a column, not a foreign key to any users table: a key
-- identifies an ACCOUNT, so it keeps working when the person who made it
-- leaves. It is also not this project's business what the application calls
-- its owners - and a plugin's Sqitch project cannot depend on the
-- application's own, which deploys last.
CREATE TABLE api_keys (
    id           bigserial PRIMARY KEY,
    owner_id     bigint  NOT NULL,
    kind         text    NOT NULL DEFAULT 'live',
    label        text    NOT NULL,
    prefix       text    NOT NULL,
    digest       text    NOT NULL,
    scopes       text,
    rate_per_min integer,
    expires      bigint,
    revoked      bigint,
    last_used    bigint,
    created      bigint  NOT NULL
);

CREATE UNIQUE INDEX api_keys_digest ON api_keys (digest);
CREATE INDEX api_keys_owner ON api_keys (owner_id);

COMMIT;
