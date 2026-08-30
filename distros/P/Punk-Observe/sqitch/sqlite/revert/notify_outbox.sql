-- Revert punk-observe:notify_outbox from sqlite

BEGIN;

DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS notification_groups;

-- The shape the alerts change deployed, restored.
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

COMMIT;
