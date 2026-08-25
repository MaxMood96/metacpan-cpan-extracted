-- Revert punk_totp:totp from mysql

ALTER TABLE users
    DROP COLUMN totp_failed_at,
    DROP COLUMN totp_failed,
    DROP COLUMN totp_enabled,
    DROP COLUMN totp_last_counter,
    DROP COLUMN totp_secret;
