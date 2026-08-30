-- Verify punk-observe:notify_outbox on sqlite

BEGIN;

SELECT id, rule_id, opened_at, due_at, state, claimed_at, sends,
       next_repeat_at, attempts
  FROM notification_groups WHERE 0;
SELECT id, rule_id, series, kind, value, at, fired_at, group_id,
       suppressed, sent_at, dead, created_at
  FROM notifications WHERE 0;

COMMIT;
