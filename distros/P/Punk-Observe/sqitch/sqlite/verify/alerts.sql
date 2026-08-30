-- Verify punk-observe:alerts on sqlite
--
-- The same columns the PostgreSQL verify names, so a schema that
-- deployed on one engine and not the other is a failure here rather
-- than a missing column found by a screen.

BEGIN;

SELECT id, tenant, slug FROM dashboards WHERE 0;
SELECT id, dashboard_id, query FROM dashboard_panels WHERE 0;
SELECT id, tenant, kind FROM notification_channels WHERE 0;
SELECT id, tenant, query, for_ns, every_ns FROM alert_rules WHERE 0;
SELECT rule_id, series, state FROM alert_state WHERE 0;
SELECT id, rule_id, kind FROM alert_events WHERE 0;
SELECT id, tenant, channel_id FROM route_rules WHERE 0;
SELECT id, tenant, pattern, until FROM silences WHERE 0;
SELECT id, rule_id, series, fired_at FROM notifications WHERE 0;
SELECT id, tenant, name, url FROM health_targets WHERE 0;
SELECT id, tenant, page, name, params FROM saved_views WHERE 0;

COMMIT;
