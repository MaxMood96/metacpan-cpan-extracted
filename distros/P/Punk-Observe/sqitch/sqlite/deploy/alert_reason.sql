-- Deploy punk-observe:alert_reason to sqlite
-- requires: notify_outbox
--
-- WHY a rule could not be evaluated, on the state row. The evaluate pass
-- turned every failure - a store error, a refused budget, an unbucketed
-- answer - into an anonymous fail tick, and the screen could only say
-- "1 rule(s) could not be evaluated" with nothing to say what was wrong.
-- The reason is written when the state is error and cleared otherwise, so
-- a recovered rule does not carry a stale explanation.

BEGIN;

ALTER TABLE alert_state ADD COLUMN reason TEXT;

COMMIT;
