-- Revert punk-observe:alert_reason from pg

BEGIN;

ALTER TABLE alert_state DROP COLUMN IF EXISTS reason;

COMMIT;
