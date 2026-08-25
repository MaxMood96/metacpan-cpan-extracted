-- Revert punk_totp:totp from sqlite (DROP COLUMN needs SQLite 3.35)

BEGIN;

ALTER TABLE users DROP COLUMN totp_failed_at;
ALTER TABLE users DROP COLUMN totp_failed;
ALTER TABLE users DROP COLUMN totp_enabled;
ALTER TABLE users DROP COLUMN totp_last_counter;
ALTER TABLE users DROP COLUMN totp_secret;

COMMIT;
