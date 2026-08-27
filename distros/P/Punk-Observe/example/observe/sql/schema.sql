-- The demo's alert database.
--
-- THIS IS THE SQLITE TWIN OF sqitch/deploy/alerts.sql, WHICH IS THE REAL ONE.
-- The shipped schema is PostgreSQL - BIGSERIAL, JSONB, TIMESTAMPTZ - because
-- that is what an application mounting this plugin is likely to already have
-- and what Punk::Sqitch deploys. A demo that required a running Postgres
-- would be a demo most people never see, so the same tables are spelled here
-- in the dialect that needs no server.
--
-- The columns and their meanings are the shipped ones. Only the types differ:
-- INTEGER PRIMARY KEY for BIGSERIAL, TEXT for JSONB, and instants as BIGINT
-- nanoseconds rather than TIMESTAMPTZ - which is arguably the better choice
-- and is certainly the one that matches everything else in this distribution.

-- ---------------------------------------------------------------------------
-- rules
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS alert_rules (
    id            INTEGER PRIMARY KEY,
    tenant        TEXT    NOT NULL,
    name          TEXT    NOT NULL,
    query         TEXT    NOT NULL,
    op            TEXT    NOT NULL
                  CHECK (op IN ('>','>=','<','<=','==','!=')),
    threshold     REAL    NOT NULL,
    -- Nanoseconds, as an integer. Never a float: a double loses the low
    -- digits of a nanosecond interval, and these are compared for equality.
    for_ns        INTEGER NOT NULL DEFAULT 0 CHECK (for_ns >= 0),
    every_ns      INTEGER NOT NULL CHECK (every_ns > 0),
    -- The label an ungrouped query's single series is shown under. An
    -- ungrouped query answers for one series whose key is the empty string,
    -- and it still has to be called something or the screen shows a rule
    -- watching a blank.
    series_label  TEXT,
    unit          TEXT,
    enabled       INTEGER NOT NULL DEFAULT 1,
    UNIQUE (tenant, name)
);

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

-- ONE ROW PER SERIES, NOT PER RULE. One state per rule is the bug that makes
-- an alert resolve because a different service recovered.
CREATE TABLE IF NOT EXISTS alert_state (
    rule_id     INTEGER NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    series      TEXT    NOT NULL,
    state       TEXT    NOT NULL
                CHECK (state IN ('ok','pending','firing','stale','error')),
    since       INTEGER,
    fired_at    INTEGER,
    last_seen   INTEGER NOT NULL,
    last_value  REAL,
    PRIMARY KEY (rule_id, series)
);

CREATE INDEX IF NOT EXISTS alert_state_firing_idx
    ON alert_state (rule_id, state);

CREATE TABLE IF NOT EXISTS alert_events (
    id          INTEGER PRIMARY KEY,
    rule_id     INTEGER NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    series      TEXT    NOT NULL,
    from_state  TEXT    NOT NULL,
    to_state    TEXT    NOT NULL,
    value       REAL,
    at          INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS alert_events_rule_idx
    ON alert_events (rule_id, at DESC);

-- ---------------------------------------------------------------------------
-- silences
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS silences (
    id          INTEGER PRIMARY KEY,
    tenant      TEXT    NOT NULL,
    pattern     TEXT    NOT NULL,
    is_prefix   INTEGER NOT NULL DEFAULT 0,
    reason      TEXT,
    created_by  TEXT,
    until       INTEGER NOT NULL
);

-- Expiry is indexed because an expired silence MUST stop suppressing: one set
-- for a deploy and forgotten is how a real page goes unsent for a month.
CREATE INDEX IF NOT EXISTS silences_active_idx ON silences (tenant, until);
