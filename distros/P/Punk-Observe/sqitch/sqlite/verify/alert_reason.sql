-- Verify punk-observe:alert_reason on sqlite

BEGIN;

SELECT rule_id, series, state, reason FROM alert_state WHERE 0;

ROLLBACK;
