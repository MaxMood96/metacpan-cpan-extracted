-- Revert punk-observe:alerts

BEGIN;

DROP TABLE IF EXISTS saved_views;
DROP TABLE IF EXISTS health_targets;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS silences;
DROP TABLE IF EXISTS route_rules;
DROP TABLE IF EXISTS alert_events;
DROP TABLE IF EXISTS alert_state;
DROP TABLE IF EXISTS alert_rules;
DROP TABLE IF EXISTS notification_channels;
DROP TABLE IF EXISTS dashboard_panels;
DROP TABLE IF EXISTS dashboards;

COMMIT;
