-- Verify apikeydemo:users on sqlite

SELECT id, email, role, suspended, created FROM users WHERE 0;
