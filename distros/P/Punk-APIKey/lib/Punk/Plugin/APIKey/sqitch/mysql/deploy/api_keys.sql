-- Deploy punk_apikey:api_keys to mysql

-- owner_id is a column, not a foreign key to any users table: a key
-- identifies an ACCOUNT, so it keeps working when the person who made it
-- leaves. It is also not this project's business what the application calls
-- its owners - and a plugin's Sqitch project cannot depend on the
-- application's own, which deploys last.
--
-- VARCHAR(191) on the indexed columns: 191 is what fits a utf8mb4 index on
-- the older row formats, and TEXT cannot be a key at all.
CREATE TABLE api_keys (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    owner_id     BIGINT NOT NULL,
    kind         VARCHAR(32) NOT NULL DEFAULT 'live',
    label        VARCHAR(191) NOT NULL,
    prefix       VARCHAR(191) NOT NULL,
    digest       VARCHAR(191) NOT NULL,
    scopes       TEXT,
    rate_per_min INTEGER,
    expires      BIGINT,
    revoked      BIGINT,
    last_used    BIGINT,
    created      BIGINT NOT NULL
);

CREATE UNIQUE INDEX api_keys_digest ON api_keys (digest);
CREATE INDEX api_keys_owner ON api_keys (owner_id);
