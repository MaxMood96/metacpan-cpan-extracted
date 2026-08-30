-- Revert punk-observe:notify_outbox from pg

BEGIN;

DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS notification_groups;

ALTER TABLE dashboards
    ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at),
    ALTER COLUMN created_at SET DEFAULT now(),
    ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING to_timestamp(updated_at),
    ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE notification_channels
    ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at),
    ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE alert_rules
    ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at),
    ALTER COLUMN created_at SET DEFAULT now(),
    ALTER COLUMN next_eval_at TYPE TIMESTAMPTZ
        USING to_timestamp(next_eval_at / 1000000000.0),
    ALTER COLUMN next_eval_at SET DEFAULT now();
ALTER TABLE alert_state
    ALTER COLUMN since     TYPE TIMESTAMPTZ USING to_timestamp(since / 1000000000.0),
    ALTER COLUMN fired_at  TYPE TIMESTAMPTZ USING to_timestamp(fired_at / 1000000000.0),
    ALTER COLUMN last_seen TYPE TIMESTAMPTZ USING to_timestamp(last_seen / 1000000000.0),
    ALTER COLUMN last_seen SET DEFAULT now();
ALTER TABLE alert_events
    ALTER COLUMN at TYPE TIMESTAMPTZ USING to_timestamp(at / 1000000000.0),
    ALTER COLUMN at SET DEFAULT now();
ALTER TABLE silences
    ALTER COLUMN until TYPE TIMESTAMPTZ USING to_timestamp(until / 1000000000.0),
    ALTER COLUMN created_at TYPE TIMESTAMPTZ USING to_timestamp(created_at),
    ALTER COLUMN created_at SET DEFAULT now();

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
    last_error  TEXT,
    dead        BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (rule_id, series, fired_at, channel_id)
);

COMMIT;
