-- Verify punk-observe:notify_outbox on pg
--
-- The same columns the SQLite verify names, plus the type conversions: an
-- instant column still TIMESTAMPTZ would take the ns bind and quietly mean
-- the wrong moment, so the cast is asserted by using one as a number.

BEGIN;

SELECT id, rule_id, opened_at, due_at, state, claimed_at, sends,
       next_repeat_at, attempts
  FROM notification_groups WHERE FALSE;
SELECT id, rule_id, series, kind, value, at, fired_at, group_id,
       suppressed, sent_at, dead, created_at
  FROM notifications WHERE FALSE;

SELECT since + 0, fired_at + 0, last_seen + 0 FROM alert_state  WHERE FALSE;
SELECT at + 0                                 FROM alert_events WHERE FALSE;
SELECT until + 0, created_at + 0              FROM silences     WHERE FALSE;
SELECT next_eval_at + 0, created_at + 0       FROM alert_rules  WHERE FALSE;
SELECT created_at + 0, updated_at + 0         FROM dashboards   WHERE FALSE;

COMMIT;
