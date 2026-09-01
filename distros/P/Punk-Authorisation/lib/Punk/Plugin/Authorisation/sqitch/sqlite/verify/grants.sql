-- Verify punk_authz:grants on sqlite

SELECT id, subject_id, action, object_id, granted_by, created
  FROM authz_grants
 WHERE 0;
