-- Deploy authzdemo:demo_data to sqlite
-- requires: user_role
-- requires: docs
--
-- The demo's fixture, as a change rather than as seeding code at boot: it is
-- revertible, it is deployed once instead of every restart, and the
-- application has no branch in it that a real one would not have.
--
-- No password_hash: nothing here signs in with a password. Picking who to be
-- is a click, because this demo is about authorisation and a login form
-- would be the only thing on the page that is not.

BEGIN;

INSERT INTO users (id, email, verified, role) VALUES
    (1, 'alice@example.com', 1, 'member'),
    (2, 'bob@example.com',   1, 'editor'),
    (3, 'carol@example.com', 1, 'admin');

INSERT INTO docs (id, title, owner_id, public) VALUES
    (1, 'Alice''s notes', 1, 0),
    (2, 'Bob''s draft',   2, 0),
    (3, 'The roadmap',    1, 1);

COMMIT;
