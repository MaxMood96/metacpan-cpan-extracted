-- Deploy punk-observe:alerts to sqlite
--
-- The metadata half. Segments hold telemetry and are immutable; everything
-- here is edited, so it lives in SQL.
--
-- GENERATED from the renderer this replaced, so it is provably the schema
-- that was being deployed rather than a translation of it. Edit it as an
-- ordinary sqitch change from here on.
--
-- Instants are INTEGER nanoseconds rather than a date type, for the reason
-- the whole distribution uses them: a nanosecond instant does not survive a
-- double, and the two engines disagree about date precision in ways that
-- would make a dashboard mean something different depending on where it was
-- stored.
--
-- Sections are ordered so a referenced table always precedes the one that
-- references it. That is not tidiness: a schema whose sections are in the
-- wrong order deploys on an empty database and fails on a real one, which is
-- the worst order in which to find out.

BEGIN;

CREATE TABLE dashboards (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant     TEXT NOT NULL,
            slug       TEXT NOT NULL,
            title      TEXT NOT NULL,
            cols       INTEGER NOT NULL DEFAULT 2,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE (tenant, slug)
        );

CREATE TABLE dashboard_panels (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            dashboard_id INTEGER NOT NULL
                         REFERENCES dashboards(id) ON DELETE CASCADE,
            position     INTEGER NOT NULL DEFAULT 0,
            title        TEXT NOT NULL,
            query        TEXT NOT NULL,
            viz          TEXT NOT NULL DEFAULT 'line',
            span         INTEGER NOT NULL DEFAULT 1
        );

CREATE INDEX dashboard_panels_dashboard_idx
              ON dashboard_panels (dashboard_id, position);

CREATE TABLE notification_channels (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant     TEXT NOT NULL,
            name       TEXT NOT NULL,
            kind       TEXT NOT NULL,
            config     TEXT,
            enabled    INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE (tenant, name)
        );

CREATE TABLE alert_rules (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant       TEXT NOT NULL,
            name         TEXT NOT NULL,
            query        TEXT NOT NULL,
            op           TEXT NOT NULL,
            threshold    REAL NOT NULL,
            for_ns       INTEGER NOT NULL DEFAULT 0,
            every_ns     INTEGER NOT NULL DEFAULT 60000000000,
            labels       TEXT,
            enabled      INTEGER NOT NULL DEFAULT 1,
            next_eval_at INTEGER NOT NULL DEFAULT 0,
            created_at   INTEGER NOT NULL DEFAULT 0,
            UNIQUE (tenant, name)
        );

CREATE INDEX alert_rules_due_idx ON alert_rules (next_eval_at);

CREATE TABLE alert_state (
            rule_id    INTEGER NOT NULL
                       REFERENCES alert_rules(id) ON DELETE CASCADE,
            series     TEXT NOT NULL,
            state      TEXT NOT NULL,
            since      INTEGER NOT NULL DEFAULT 0,
            fired_at   INTEGER,
            last_seen  INTEGER NOT NULL DEFAULT 0,
            last_value REAL,
            PRIMARY KEY (rule_id, series)
        );

CREATE TABLE alert_events (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_id    INTEGER NOT NULL
                       REFERENCES alert_rules(id) ON DELETE CASCADE,
            series     TEXT NOT NULL,
            kind       INTEGER NOT NULL,
            from_state TEXT,
            to_state   TEXT,
            value      REAL,
            at         INTEGER NOT NULL DEFAULT 0
        );

CREATE INDEX alert_events_rule_idx ON alert_events (rule_id, at);

CREATE TABLE route_rules (
            id                 INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant             TEXT NOT NULL,
            position           INTEGER NOT NULL DEFAULT 0,
            match_labels       TEXT,
            group_by           TEXT,
            channel_id         INTEGER REFERENCES notification_channels(id),
            group_wait_ns      INTEGER NOT NULL DEFAULT 30000000000,
            repeat_interval_ns INTEGER NOT NULL DEFAULT 14400000000000
        );

CREATE INDEX route_rules_tenant_idx ON route_rules (tenant, position);

CREATE TABLE silences (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant     TEXT NOT NULL,
            pattern    TEXT NOT NULL,
            is_prefix  INTEGER NOT NULL DEFAULT 0,
            reason     TEXT,
            created_by TEXT,
            until      INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0
        );

CREATE INDEX silences_active_idx ON silences (tenant, until);

CREATE TABLE notifications (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_id    INTEGER NOT NULL
                       REFERENCES alert_rules(id) ON DELETE CASCADE,
            series     TEXT NOT NULL,
            fired_at   INTEGER NOT NULL,
            channel_id INTEGER REFERENCES notification_channels(id),
            payload    TEXT,
            claimed_at INTEGER,
            sent_at    INTEGER,
            attempts   INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            dead       INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE (rule_id, series, fired_at, channel_id)
        );

CREATE INDEX notifications_unsent_idx ON notifications (created_at);

CREATE TABLE health_targets (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant     TEXT NOT NULL,
            name       TEXT NOT NULL,
            url        TEXT NOT NULL,
            -- Nanoseconds, as everything else in this distribution is. A
            -- double loses the low digits of an interval and these are
            -- compared for equality.
            every_ns   INTEGER NOT NULL DEFAULT 60000000000,
            -- Milliseconds, because it is passed to an HTTP client that
            -- thinks in them. A target with no timeout blocks the runner
            -- behind it.
            timeout_ms INTEGER NOT NULL DEFAULT 5000,
            enabled    INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE (tenant, name)
        );

CREATE INDEX health_targets_due_idx ON health_targets (tenant, enabled);

CREATE TABLE saved_views (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant     TEXT NOT NULL,
            page       TEXT NOT NULL,
            name       TEXT NOT NULL,
            params     TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0,
            UNIQUE (tenant, page, name)
        );

CREATE INDEX saved_views_page_idx ON saved_views (tenant, page, name);

COMMIT;
