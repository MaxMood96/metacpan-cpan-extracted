-- Verify authzdemo:demo_data on sqlite

SELECT 1/count(*) FROM users WHERE email = 'carol@example.com';
