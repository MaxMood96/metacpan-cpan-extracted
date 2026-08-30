-- Deploy punk-observe:notify_outbox to sqlite
--
-- The persistent half of notification routing. po_route.h's grouping is
-- in-memory, and group_wait has to survive process death - a group opened
-- forty seconds before a crash still owes somebody a page - so the state
-- lives here and the evaluate pass drives it with SQL.
--
-- notifications IS RECREATED, NOT ALTERED. It has never had a writer - the
-- table shipped with the schema and nothing in any release inserted a row -
-- so there is nothing to migrate, and recreating it fixes what the original
-- shape got wrong:
--
--   * the UNIQUE key included the nullable channel_id, and NULLs are
--     distinct in unique indexes on both engines, so for callback delivery
--     (no channel row) the dedupe NEVER FIRED;
--   * keyed on fired_at alone, a second error-kind episode - fired_at is 0
--     when a rule cannot evaluate - collided with the first and was silently
--     dropped. The key is now THE TRANSITION ITSELF: (rule, series,
--     fired_at, at). A re-run of the same pass recomputes the same
--     instants and is refused; a resolve-and-refire carries new ones and is
--     a new notification.

BEGIN;

DROP TABLE IF EXISTS notifications;

-- One row per delivery episode of one rule. The group is what group_wait
-- holds and what one callback invocation covers: one bad deploy is one
-- message listing forty series, not forty messages.
CREATE TABLE notification_groups (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_id        INTEGER NOT NULL
                   REFERENCES alert_rules(id) ON DELETE CASCADE,
    opened_at      INTEGER NOT NULL,
    due_at         INTEGER NOT NULL,
    state          TEXT NOT NULL DEFAULT 'open'
                   CHECK (state IN ('open','claimed','sent','dead')),
    claimed_at     INTEGER,
    sent_at        INTEGER,
    last_sent_at   INTEGER,
    sends          INTEGER NOT NULL DEFAULT 0,
    next_repeat_at INTEGER,
    attempts       INTEGER NOT NULL DEFAULT 0,
    last_error     TEXT
);

-- AT MOST ONE OPEN GROUP PER RULE, structurally. A member arriving while
-- the rule's group is claimed, sent or dead finds no open group and opens a
-- new one - which is exactly "the forty-first service is a second
-- notification, not a lost one", enforced by an index rather than by code
-- remembering to.
CREATE UNIQUE INDEX ngroups_open_idx
    ON notification_groups (rule_id) WHERE state = 'open';
CREATE INDEX ngroups_due_idx
    ON notification_groups (due_at) WHERE state = 'open';
CREATE INDEX ngroups_repeat_idx
    ON notification_groups (next_repeat_at) WHERE state = 'sent';

CREATE TABLE notifications (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_id    INTEGER NOT NULL
               REFERENCES alert_rules(id) ON DELETE CASCADE,
    series     TEXT NOT NULL,
    kind       INTEGER NOT NULL,             -- 1 firing 2 resolved 3 vanished 4 error
    value      REAL,
    at         INTEGER NOT NULL,             -- the transition instant, ns
    fired_at   INTEGER NOT NULL DEFAULT 0,   -- the episode; 0 for error kind
    group_id   INTEGER
               REFERENCES notification_groups(id) ON DELETE SET NULL,
    -- A silence RECORDS its suppression rather than hiding it: the row
    -- survives, the flag says why nobody was paged, and the dedupe key
    -- still refuses a duplicate of the suppressed fire.
    suppressed INTEGER NOT NULL DEFAULT 0,
    sent_at    INTEGER,
    dead       INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at INTEGER NOT NULL DEFAULT 0,
    UNIQUE (rule_id, series, fired_at, at)
);

CREATE INDEX notifications_group_idx ON notifications (group_id);

COMMIT;
