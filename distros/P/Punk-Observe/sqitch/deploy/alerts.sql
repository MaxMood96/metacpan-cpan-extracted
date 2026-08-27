-- Deploy punk-observe:alerts
--
-- The metadata half. Segments hold telemetry and are immutable; everything
-- here is edited, so it lives in SQL.
--
-- Sections are ordered so a referenced table always precedes the one that
-- references it. That is not tidiness: a schema whose sections are in the
-- wrong order deploys on an empty database and fails on a real one, which is
-- the worst order in which to find out.

BEGIN;

-- ---------------------------------------------------------------------------
-- dashboards
-- ---------------------------------------------------------------------------

CREATE TABLE dashboards (
    id          BIGSERIAL PRIMARY KEY,
    tenant      TEXT        NOT NULL,
    slug        TEXT        NOT NULL,
    title       TEXT        NOT NULL,
    cols        SMALLINT    NOT NULL DEFAULT 2 CHECK (cols BETWEEN 1 AND 6),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant, slug)
);

-- A panel is an OQL string. It is validated by the parser that will execute
-- it before it ever reaches this table, so a stored panel always renders.
CREATE TABLE dashboard_panels (
    id           BIGSERIAL PRIMARY KEY,
    dashboard_id BIGINT      NOT NULL REFERENCES dashboards(id) ON DELETE CASCADE,
    position     INTEGER     NOT NULL DEFAULT 0,
    title        TEXT        NOT NULL,
    query        TEXT        NOT NULL,
    viz          TEXT        NOT NULL DEFAULT 'line',
    span         SMALLINT    NOT NULL DEFAULT 1 CHECK (span BETWEEN 1 AND 6)
);

CREATE INDEX dashboard_panels_dashboard_idx
    ON dashboard_panels (dashboard_id, position);

-- ---------------------------------------------------------------------------
-- notification channels
-- ---------------------------------------------------------------------------

-- config is JSONB and holds a webhook URL or an address list. A WEBHOOK URL
-- IS FREQUENTLY THE CREDENTIAL, so it is written through the secret forms,
-- redacted in any dump, and never logged.
CREATE TABLE notification_channels (
    id          BIGSERIAL PRIMARY KEY,
    tenant      TEXT        NOT NULL,
    name        TEXT        NOT NULL,
    kind        TEXT        NOT NULL CHECK (kind IN ('email', 'webhook')),
    config      JSONB       NOT NULL DEFAULT '{}'::jsonb,
    enabled     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant, name)
);

-- ---------------------------------------------------------------------------
-- rules
-- ---------------------------------------------------------------------------

CREATE TABLE alert_rules (
    id            BIGSERIAL PRIMARY KEY,
    tenant        TEXT        NOT NULL,
    name          TEXT        NOT NULL,
    query         TEXT        NOT NULL,
    op            TEXT        NOT NULL CHECK (op IN ('>','>=','<','<=','==','!=')),
    threshold     DOUBLE PRECISION NOT NULL,
    -- Nanoseconds, as BIGINT. Never a float: a double loses the low digits of
    -- a nanosecond interval, and these are compared for equality.
    for_ns        BIGINT      NOT NULL DEFAULT 0 CHECK (for_ns >= 0),
    every_ns      BIGINT      NOT NULL CHECK (every_ns > 0),
    labels        JSONB       NOT NULL DEFAULT '{}'::jsonb,
    enabled       BOOLEAN     NOT NULL DEFAULT TRUE,
    next_eval_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant, name)
);

-- The evaluator claims work with FOR UPDATE SKIP LOCKED on this index, so
-- several evaluators are safe even though leader election means there is
-- normally one. Belt and braces is worth having when the alternative is
-- duplicate pages.
CREATE INDEX alert_rules_due_idx
    ON alert_rules (next_eval_at) WHERE enabled;

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

-- ONE ROW PER SERIES, NOT PER RULE. One state per rule is the bug that makes
-- an alert resolve because a different service recovered.
CREATE TABLE alert_state (
    rule_id     BIGINT      NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    series      TEXT        NOT NULL,
    state       TEXT        NOT NULL
                CHECK (state IN ('ok','pending','firing','stale','error')),
    since       TIMESTAMPTZ,
    fired_at    TIMESTAMPTZ,
    last_seen   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_value  DOUBLE PRECISION,
    PRIMARY KEY (rule_id, series)
);

CREATE INDEX alert_state_firing_idx
    ON alert_state (rule_id) WHERE state IN ('firing', 'error');

CREATE TABLE alert_events (
    id          BIGSERIAL PRIMARY KEY,
    rule_id     BIGINT      NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    series      TEXT        NOT NULL,
    kind        SMALLINT    NOT NULL,   -- 1 firing 2 resolved 3 vanished 4 error
    from_state  TEXT        NOT NULL,
    to_state    TEXT        NOT NULL,
    value       DOUBLE PRECISION,
    at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX alert_events_rule_idx ON alert_events (rule_id, at DESC);

-- ---------------------------------------------------------------------------
-- routing and silences
-- ---------------------------------------------------------------------------

CREATE TABLE route_rules (
    id                  BIGSERIAL PRIMARY KEY,
    tenant              TEXT     NOT NULL,
    position            INTEGER  NOT NULL DEFAULT 0,
    match_labels        JSONB    NOT NULL DEFAULT '{}'::jsonb,
    group_by            JSONB    NOT NULL DEFAULT '[]'::jsonb,
    channel_id          BIGINT   NOT NULL REFERENCES notification_channels(id)
                                 ON DELETE CASCADE,
    group_wait_ns       BIGINT   NOT NULL DEFAULT 30000000000,
    repeat_interval_ns  BIGINT   NOT NULL DEFAULT 14400000000000
);

CREATE INDEX route_rules_tenant_idx ON route_rules (tenant, position);

-- A silence suppresses NOTIFICATION and not STATE, which is why nothing here
-- is referenced by alert_state.
CREATE TABLE silences (
    id          BIGSERIAL PRIMARY KEY,
    tenant      TEXT        NOT NULL,
    pattern     TEXT        NOT NULL,
    is_prefix   BOOLEAN     NOT NULL DEFAULT FALSE,
    reason      TEXT,
    created_by  TEXT,
    until       TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Expiry is indexed because an expired silence MUST stop suppressing: one set
-- for a deploy and forgotten is how a real page goes unsent for a month.
CREATE INDEX silences_active_idx ON silences (tenant, until);

-- ---------------------------------------------------------------------------
-- the outbox
-- ---------------------------------------------------------------------------

-- THE DEDUPE KEY IS (rule, series, fired_at). A retried job recomputes the
-- same key and the unique constraint refuses it, so a delivery can never
-- happen twice however many times the job runs.
--
-- fired_at is in the key rather than the time of the send, because a series
-- that resolves and fires again is a NEW notification and must not be
-- deduplicated against the old one.
CREATE TABLE notifications (
    id          BIGSERIAL PRIMARY KEY,
    rule_id     BIGINT      NOT NULL REFERENCES alert_rules(id) ON DELETE CASCADE,
    series      TEXT        NOT NULL,
    fired_at    TIMESTAMPTZ NOT NULL,
    channel_id  BIGINT      NOT NULL REFERENCES notification_channels(id)
                            ON DELETE CASCADE,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    claimed_at  TIMESTAMPTZ,
    sent_at     TIMESTAMPTZ,
    attempts    SMALLINT    NOT NULL DEFAULT 0,
    -- A dead letter is RECORDED, not dropped. A notification that failed and
    -- left no trace is indistinguishable from one that was never generated.
    last_error  TEXT,
    dead        BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rule_id, series, fired_at, channel_id)
);

-- The sender's claim query: unsent, not dead, oldest first, SKIP LOCKED.
CREATE INDEX notifications_unsent_idx
    ON notifications (created_at)
    WHERE sent_at IS NULL AND NOT dead;

COMMIT;
