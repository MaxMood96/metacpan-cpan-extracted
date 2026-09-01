-- Deploy authzdemo:user_role to sqlite
-- requires: punk_auth:users
--
-- The rung. punk_auth's users table is the one the `auth` keyword ships and
-- it has no opinion about roles, so the application that wants a ladder adds
-- the column - which is what a cross-project dependency is for.

BEGIN;

ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'member';

COMMIT;
