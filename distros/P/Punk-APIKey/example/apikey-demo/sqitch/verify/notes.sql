-- Verify apikeydemo:notes on sqlite

SELECT id, owner_id, body, created FROM notes WHERE 0;
