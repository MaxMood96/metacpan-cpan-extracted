-- Deploy punk_authz:grants to mysql
-- VARCHAR rather than TEXT on the indexed columns: MySQL cannot put a unique
-- index on TEXT without a prefix length.

CREATE TABLE authz_grants (
    id         BIGINT       PRIMARY KEY AUTO_INCREMENT,
    subject_id BIGINT       NOT NULL,
    action     VARCHAR(191) NOT NULL,
    object_id  VARCHAR(191) NOT NULL,
    granted_by BIGINT,
    created    BIGINT,
    UNIQUE KEY authz_grants_one (subject_id, action, object_id),
    KEY authz_grants_object (action, object_id)
);
