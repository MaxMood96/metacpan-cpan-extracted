-- Deploy punk-observe:notify_outbox to pg
--
-- Two things, and the first is owed from before this change.
--
-- EVERY INSTANT BECOMES BIGINT. The house rule - stated in the SQLite twin
-- and in every module POD - is that instants are integer columns, because a
-- nanosecond does not survive a timestamp type's precision and the two
-- engines disagree about that precision in ways that would make the same row
-- mean different moments. This script predated the rule: the code binds
-- decimal nanoseconds (state, events, silences) and epoch seconds
-- (created_at columns) into TIMESTAMPTZ, which PostgreSQL either refuses or
-- quietly reinterprets. Converted here, with the unit each column's writer
-- actually binds; the tables are young enough that USING covers what exists.
--
-- And the persistent half of notification routing - see the SQLite twin for
-- the full argument. notifications is RECREATED, not altered: it never had
-- a writer, so there is nothing to migrate, and the original shape's dedupe
-- key never fired (it included the nullable channel_id, and NULLs are
-- distinct in unique indexes).

BEGIN;

-- seconds columns: the writers bind time()
ALTER TABLE dashboards
    ALTER COLUMN created_at DROP DEFAULT,
    ALTER COLUMN created_at TYPE BIGINT
        USING (extract(epoch FROM created_at))::bigint,
    ALTER COLUMN created_at SET DEFAULT 0,
    ALTER COLUMN updated_at DROP DEFAULT,
    ALTER COLUMN updated_at TYPE BIGINT
        USING (extract(epoch FROM updated_at))::bigint,
    ALTER COLUMN updated_at SET DEFAULT 0;

ALTER TABLE notification_channels
    ALTER COLUMN created_at DROP DEFAULT,
    ALTER COLUMN created_at TYPE BIGINT
        USING (extract(epoch FROM created_at))::bigint,
    ALTER COLUMN created_at SET DEFAULT 0;

ALTER TABLE alert_rules
    ALTER COLUMN created_at DROP DEFAULT,
    ALTER COLUMN created_at TYPE BIGINT
        USING (extract(epoch FROM created_at))::bigint,
    ALTER COLUMN created_at SET DEFAULT 0,
    -- nanoseconds: the evaluator's due tracking
    ALTER COLUMN next_eval_at DROP DEFAULT,
    ALTER COLUMN next_eval_at TYPE BIGINT
        USING (extract(epoch FROM next_eval_at) * 1000000000)::bigint,
    ALTER COLUMN next_eval_at SET DEFAULT 0;

-- nanosecond columns: the evaluator and the reader bind decimal ns
ALTER TABLE alert_state
    ALTER COLUMN since     TYPE BIGINT
        USING (extract(epoch FROM since) * 1000000000)::bigint,
    ALTER COLUMN fired_at  TYPE BIGINT
        USING (extract(epoch FROM fired_at) * 1000000000)::bigint,
    ALTER COLUMN last_seen DROP DEFAULT,
    ALTER COLUMN last_seen TYPE BIGINT
        USING (extract(epoch FROM last_seen) * 1000000000)::bigint,
    ALTER COLUMN last_seen SET DEFAULT 0;

ALTER TABLE alert_events
    ALTER COLUMN at DROP DEFAULT,
    ALTER COLUMN at TYPE BIGINT
        USING (extract(epoch FROM at) * 1000000000)::bigint,
    ALTER COLUMN at SET DEFAULT 0;

ALTER TABLE silences
    ALTER COLUMN until TYPE BIGINT
        USING (extract(epoch FROM until) * 1000000000)::bigint,
    ALTER COLUMN created_at DROP DEFAULT,
    ALTER COLUMN created_at TYPE BIGINT
        USING (extract(epoch FROM created_at))::bigint,
    ALTER COLUMN created_at SET DEFAULT 0;

DROP TABLE notifications;

-- One row per delivery episode of one rule. The group is what group_wait
-- holds and what one callback invocation covers: one bad deploy is one
-- message listing forty series, not forty messages.
CREATE TABLE notification_groups (
    id             BIGSERIAL PRIMARY KEY,
    rule_id        BIGINT NOT NULL
                   REFERENCES alert_rules(id) ON DELETE CASCADE,
    opened_at      BIGINT NOT NULL,
    due_at         BIGINT NOT NULL,
    state          TEXT NOT NULL DEFAULT 'open'
                   CHECK (state IN ('open','claimed','sent','dead')),
    claimed_at     BIGINT,
    sent_at        BIGINT,
    last_sent_at   BIGINT,
    sends          INTEGER NOT NULL DEFAULT 0,
    next_repeat_at BIGINT,
    attempts       INTEGER NOT NULL DEFAULT 0,
    last_error     TEXT
);

-- AT MOST ONE OPEN GROUP PER RULE, structurally. A member arriving while
-- the rule's group is claimed, sent or dead finds no open group and opens a
-- new one - "the forty-first service is a second notification, not a lost
-- one", enforced by an index rather than by code remembering to.
CREATE UNIQUE INDEX ngroups_open_idx
    ON notification_groups (rule_id) WHERE state = 'open';
CREATE INDEX ngroups_due_idx
    ON notification_groups (due_at) WHERE state = 'open';
CREATE INDEX ngroups_repeat_idx
    ON notification_groups (next_repeat_at) WHERE state = 'sent';

CREATE TABLE notifications (
    id         BIGSERIAL PRIMARY KEY,
    rule_id    BIGINT NOT NULL
               REFERENCES alert_rules(id) ON DELETE CASCADE,
    series     TEXT NOT NULL,
    kind       INTEGER NOT NULL,            -- 1 firing 2 resolved 3 vanished 4 error
    value      DOUBLE PRECISION,
    at         BIGINT NOT NULL,             -- the transition instant, ns
    fired_at   BIGINT NOT NULL DEFAULT 0,   -- the episode; 0 for error kind
    group_id   BIGINT
               REFERENCES notification_groups(id) ON DELETE SET NULL,
    -- A silence RECORDS its suppression rather than hiding it: the row
    -- survives, the flag says why nobody was paged, and the dedupe key
    -- still refuses a duplicate of the suppressed fire.
    suppressed BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at    BIGINT,
    dead       BOOLEAN NOT NULL DEFAULT FALSE,
    last_error TEXT,
    created_at BIGINT NOT NULL DEFAULT 0,
    UNIQUE (rule_id, series, fired_at, at)
);

CREATE INDEX notifications_group_idx ON notifications (group_id);

COMMIT;
