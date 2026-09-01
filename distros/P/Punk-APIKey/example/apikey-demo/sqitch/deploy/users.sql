-- Deploy apikeydemo:users to sqlite

BEGIN;

-- `role` is a rung on the ladder the `auth` keyword declares, and
-- `suspended` is what makes a key stop working without revoking it: the
-- APIKey plugin reads both through owner_model on every guarded request.
CREATE TABLE users (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    email     TEXT    NOT NULL,
    role      TEXT    NOT NULL DEFAULT 'member',
    suspended INTEGER,                    -- epoch; null is good standing
    created   INTEGER NOT NULL
);

CREATE UNIQUE INDEX users_email ON users (email);

COMMIT;
