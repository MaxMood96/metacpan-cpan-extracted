-- Verify punk-observe:alerts

BEGIN;

SELECT id, tenant, slug FROM dashboards WHERE FALSE;
SELECT id, dashboard_id, query FROM dashboard_panels WHERE FALSE;
SELECT id, tenant, kind FROM notification_channels WHERE FALSE;
SELECT id, tenant, query, for_ns, every_ns FROM alert_rules WHERE FALSE;
SELECT rule_id, series, state FROM alert_state WHERE FALSE;
SELECT id, rule_id, kind FROM alert_events WHERE FALSE;
SELECT id, tenant, channel_id FROM route_rules WHERE FALSE;
SELECT id, tenant, pattern, until FROM silences WHERE FALSE;
SELECT id, rule_id, series, fired_at FROM notifications WHERE FALSE;

ROLLBACK;
