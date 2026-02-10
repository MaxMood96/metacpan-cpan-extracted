package SPVM::DBI::Constant;



1;

=encoding utf8

=head1 Name

SPVM::DBI::Constant - Database Information and Capability Constants

=head1 Description

L<SPVM::DBI::Constant> class in L<SPVM> defines various constants used by the L<DBI|SPVM::DBI> interface. 

These constants are primarily used as arguments for the C<get_info> method in L<DBI::Db|SPVM::DBI::Db> to query database-specific information, such as supported features, data types, and limitations.

=head1 Usage

  use DBI::Constant;

=head1 Class Methods

=head2 SQL_ACCESSIBLE_PROCEDURES

C<static method SQL_ACCESSIBLE_PROCEDURES : int ();>

Returns 20.

=head2 SQL_ACCESSIBLE_TABLES

C<static method SQL_ACCESSIBLE_TABLES : int ();>

Returns 19.

=head2 SQL_ACTIVE_CONNECTIONS

C<static method SQL_ACTIVE_CONNECTIONS : int ();>

Returns 0.

=head2 SQL_ACTIVE_ENVIRONMENTS

C<static method SQL_ACTIVE_ENVIRONMENTS : int ();>

Returns 116.

=head2 SQL_ACTIVE_STATEMENTS

C<static method SQL_ACTIVE_STATEMENTS : int ();>

Returns 1.

=head2 SQL_AD_ADD_CONSTRAINT_DEFERRABLE

C<static method SQL_AD_ADD_CONSTRAINT_DEFERRABLE : int ();>

Returns 128.

=head2 SQL_AD_ADD_CONSTRAINT_INITIALLY_DEFERRED

C<static method SQL_AD_ADD_CONSTRAINT_INITIALLY_DEFERRED : int ();>

Returns 32.

=head2 SQL_AD_ADD_CONSTRAINT_INITIALLY_IMMEDIATE

C<static method SQL_AD_ADD_CONSTRAINT_INITIALLY_IMMEDIATE : int ();>

Returns 64.

=head2 SQL_AD_ADD_CONSTRAINT_NON_DEFERRABLE

C<static method SQL_AD_ADD_CONSTRAINT_NON_DEFERRABLE : int ();>

Returns 256.

=head2 SQL_AD_ADD_DOMAIN_CONSTRAINT

C<static method SQL_AD_ADD_DOMAIN_CONSTRAINT : int ();>

Returns 2.

=head2 SQL_AD_ADD_DOMAIN_DEFAULT

C<static method SQL_AD_ADD_DOMAIN_DEFAULT : int ();>

Returns 8.

=head2 SQL_AD_CONSTRAINT_NAME_DEFINITION

C<static method SQL_AD_CONSTRAINT_NAME_DEFINITION : int ();>

Returns 1.

=head2 SQL_AD_DROP_DOMAIN_CONSTRAINT

C<static method SQL_AD_DROP_DOMAIN_CONSTRAINT : int ();>

Returns 4.

=head2 SQL_AD_DROP_DOMAIN_DEFAULT

C<static method SQL_AD_DROP_DOMAIN_DEFAULT : int ();>

Returns 16.

=head2 SQL_AF_ALL

C<static method SQL_AF_ALL : int ();>

Returns 64.

=head2 SQL_AF_AVG

C<static method SQL_AF_AVG : int ();>

Returns 1.

=head2 SQL_AF_COUNT

C<static method SQL_AF_COUNT : int ();>

Returns 2.

=head2 SQL_AF_DISTINCT

C<static method SQL_AF_DISTINCT : int ();>

Returns 32.

=head2 SQL_AF_MAX

C<static method SQL_AF_MAX : int ();>

Returns 4.

=head2 SQL_AF_MIN

C<static method SQL_AF_MIN : int ();>

Returns 8.

=head2 SQL_AF_SUM

C<static method SQL_AF_SUM : int ();>

Returns 16.

=head2 SQL_AGGREGATE_FUNCTIONS

C<static method SQL_AGGREGATE_FUNCTIONS : int ();>

Returns 169.

=head2 SQL_ALTER_DOMAIN

C<static method SQL_ALTER_DOMAIN : int ();>

Returns 117.

=head2 SQL_ALTER_TABLE

C<static method SQL_ALTER_TABLE : int ();>

Returns 86.

=head2 SQL_AM_CONNECTION

C<static method SQL_AM_CONNECTION : int ();>

Returns 1.

=head2 SQL_AM_NONE

C<static method SQL_AM_NONE : int ();>

Returns 0.

=head2 SQL_AM_STATEMENT

C<static method SQL_AM_STATEMENT : int ();>

Returns 2.

=head2 SQL_ASYNC_MODE

C<static method SQL_ASYNC_MODE : int ();>

Returns 10021.

=head2 SQL_AT_ADD_COLUMN_COLLATION

C<static method SQL_AT_ADD_COLUMN_COLLATION : int ();>

Returns 128.

=head2 SQL_AT_ADD_COLUMN_DEFAULT

C<static method SQL_AT_ADD_COLUMN_DEFAULT : int ();>

Returns 64.

=head2 SQL_AT_ADD_COLUMN

C<static method SQL_AT_ADD_COLUMN : int ();>

Returns 1.

=head2 SQL_AT_ADD_COLUMN_SINGLE

C<static method SQL_AT_ADD_COLUMN_SINGLE : int ();>

Returns 32.

=head2 SQL_AT_ADD_CONSTRAINT

C<static method SQL_AT_ADD_CONSTRAINT : int ();>

Returns 8.

=head2 SQL_AT_ADD_TABLE_CONSTRAINT

C<static method SQL_AT_ADD_TABLE_CONSTRAINT : int ();>

Returns 4096.

=head2 SQL_AT_ALTER_COLUMN

C<static method SQL_AT_ALTER_COLUMN : int ();>

Returns 4.

=head2 SQL_AT_CONSTRAINT_DEFERRABLE

C<static method SQL_AT_CONSTRAINT_DEFERRABLE : int ();>

Returns 262144.

=head2 SQL_AT_CONSTRAINT_INITIALLY_DEFERRED

C<static method SQL_AT_CONSTRAINT_INITIALLY_DEFERRED : int ();>

Returns 65536.

=head2 SQL_AT_CONSTRAINT_INITIALLY_IMMEDIATE

C<static method SQL_AT_CONSTRAINT_INITIALLY_IMMEDIATE : int ();>

Returns 131072.

=head2 SQL_AT_CONSTRAINT_NAME_DEFINITION

C<static method SQL_AT_CONSTRAINT_NAME_DEFINITION : int ();>

Returns 32768.

=head2 SQL_AT_CONSTRAINT_NON_DEFERRABLE

C<static method SQL_AT_CONSTRAINT_NON_DEFERRABLE : int ();>

Returns 524288.

=head2 SQL_AT_DROP_COLUMN_CASCADE

C<static method SQL_AT_DROP_COLUMN_CASCADE : int ();>

Returns 1024.

=head2 SQL_AT_DROP_COLUMN_DEFAULT

C<static method SQL_AT_DROP_COLUMN_DEFAULT : int ();>

Returns 512.

=head2 SQL_AT_DROP_COLUMN

C<static method SQL_AT_DROP_COLUMN : int ();>

Returns 2.

=head2 SQL_AT_DROP_COLUMN_RESTRICT

C<static method SQL_AT_DROP_COLUMN_RESTRICT : int ();>

Returns 2048.

=head2 SQL_AT_DROP_CONSTRAINT

C<static method SQL_AT_DROP_CONSTRAINT : int ();>

Returns 16.

=head2 SQL_AT_DROP_TABLE_CONSTRAINT_CASCADE

C<static method SQL_AT_DROP_TABLE_CONSTRAINT_CASCADE : int ();>

Returns 8192.

=head2 SQL_AT_DROP_TABLE_CONSTRAINT_RESTRICT

C<static method SQL_AT_DROP_TABLE_CONSTRAINT_RESTRICT : int ();>

Returns 16384.

=head2 SQL_AT_SET_COLUMN_DEFAULT

C<static method SQL_AT_SET_COLUMN_DEFAULT : int ();>

Returns 256.

=head2 SQL_BATCH_ROW_COUNT

C<static method SQL_BATCH_ROW_COUNT : int ();>

Returns 120.

=head2 SQL_BATCH_SUPPORT

C<static method SQL_BATCH_SUPPORT : int ();>

Returns 121.

=head2 SQL_BOOKMARK_PERSISTENCE

C<static method SQL_BOOKMARK_PERSISTENCE : int ();>

Returns 82.

=head2 SQL_BP_CLOSE

C<static method SQL_BP_CLOSE : int ();>

Returns 1.

=head2 SQL_BP_DELETE

C<static method SQL_BP_DELETE : int ();>

Returns 2.

=head2 SQL_BP_DROP

C<static method SQL_BP_DROP : int ();>

Returns 4.

=head2 SQL_BP_OTHER_HSTMT

C<static method SQL_BP_OTHER_HSTMT : int ();>

Returns 32.

=head2 SQL_BP_SCROLL

C<static method SQL_BP_SCROLL : int ();>

Returns 64.

=head2 SQL_BP_TRANSACTION

C<static method SQL_BP_TRANSACTION : int ();>

Returns 8.

=head2 SQL_BP_UPDATE

C<static method SQL_BP_UPDATE : int ();>

Returns 16.

=head2 SQL_BRC_EXPLICIT

C<static method SQL_BRC_EXPLICIT : int ();>

Returns 2.

=head2 SQL_BRC_PROCEDURES

C<static method SQL_BRC_PROCEDURES : int ();>

Returns 1.

=head2 SQL_BRC_ROLLED_UP

C<static method SQL_BRC_ROLLED_UP : int ();>

Returns 4.

=head2 SQL_BS_ROW_COUNT_EXPLICIT

C<static method SQL_BS_ROW_COUNT_EXPLICIT : int ();>

Returns 2.

=head2 SQL_BS_ROW_COUNT_PROC

C<static method SQL_BS_ROW_COUNT_PROC : int ();>

Returns 8.

=head2 SQL_BS_SELECT_EXPLICIT

C<static method SQL_BS_SELECT_EXPLICIT : int ();>

Returns 1.

=head2 SQL_BS_SELECT_PROC

C<static method SQL_BS_SELECT_PROC : int ();>

Returns 4.

=head2 SQL_CA1_ABSOLUTE

C<static method SQL_CA1_ABSOLUTE : int ();>

Returns 2.

=head2 SQL_CA1_BOOKMARK

C<static method SQL_CA1_BOOKMARK : int ();>

Returns 8.

=head2 SQL_CA1_BULK_ADD

C<static method SQL_CA1_BULK_ADD : int ();>

Returns 65536.

=head2 SQL_CA1_BULK_DELETE_BY_BOOKMARK

C<static method SQL_CA1_BULK_DELETE_BY_BOOKMARK : int ();>

Returns 262144.

=head2 SQL_CA1_BULK_FETCH_BY_BOOKMARK

C<static method SQL_CA1_BULK_FETCH_BY_BOOKMARK : int ();>

Returns 524288.

=head2 SQL_CA1_BULK_UPDATE_BY_BOOKMARK

C<static method SQL_CA1_BULK_UPDATE_BY_BOOKMARK : int ();>

Returns 131072.

=head2 SQL_CA1_LOCK_EXCLUSIVE

C<static method SQL_CA1_LOCK_EXCLUSIVE : int ();>

Returns 128.

=head2 SQL_CA1_LOCK_NO_CHANGE

C<static method SQL_CA1_LOCK_NO_CHANGE : int ();>

Returns 64.

=head2 SQL_CA1_LOCK_UNLOCK

C<static method SQL_CA1_LOCK_UNLOCK : int ();>

Returns 256.

=head2 SQL_CA1_NEXT

C<static method SQL_CA1_NEXT : int ();>

Returns 1.

=head2 SQL_CA1_POS_DELETE

C<static method SQL_CA1_POS_DELETE : int ();>

Returns 2048.

=head2 SQL_CA1_POSITIONED_DELETE

C<static method SQL_CA1_POSITIONED_DELETE : int ();>

Returns 16384.

=head2 SQL_CA1_POSITIONED_UPDATE

C<static method SQL_CA1_POSITIONED_UPDATE : int ();>

Returns 8192.

=head2 SQL_CA1_POS_POSITION

C<static method SQL_CA1_POS_POSITION : int ();>

Returns 512.

=head2 SQL_CA1_POS_REFRESH

C<static method SQL_CA1_POS_REFRESH : int ();>

Returns 4096.

=head2 SQL_CA1_POS_UPDATE

C<static method SQL_CA1_POS_UPDATE : int ();>

Returns 1024.

=head2 SQL_CA1_RELATIVE

C<static method SQL_CA1_RELATIVE : int ();>

Returns 4.

=head2 SQL_CA1_SELECT_FOR_UPDATE

C<static method SQL_CA1_SELECT_FOR_UPDATE : int ();>

Returns 32768.

=head2 SQL_CA2_CRC_APPROXIMATE

C<static method SQL_CA2_CRC_APPROXIMATE : int ();>

Returns 8192.

=head2 SQL_CA2_CRC_EXACT

C<static method SQL_CA2_CRC_EXACT : int ();>

Returns 4096.

=head2 SQL_CA2_LOCK_CONCURRENCY

C<static method SQL_CA2_LOCK_CONCURRENCY : int ();>

Returns 2.

=head2 SQL_CA2_MAX_ROWS_CATALOG

C<static method SQL_CA2_MAX_ROWS_CATALOG : int ();>

Returns 2048.

=head2 SQL_CA2_MAX_ROWS_DELETE

C<static method SQL_CA2_MAX_ROWS_DELETE : int ();>

Returns 512.

=head2 SQL_CA2_MAX_ROWS_INSERT

C<static method SQL_CA2_MAX_ROWS_INSERT : int ();>

Returns 256.

=head2 SQL_CA2_MAX_ROWS_SELECT

C<static method SQL_CA2_MAX_ROWS_SELECT : int ();>

Returns 128.

=head2 SQL_CA2_MAX_ROWS_UPDATE

C<static method SQL_CA2_MAX_ROWS_UPDATE : int ();>

Returns 1024.

=head2 SQL_CA2_OPT_ROWVER_CONCURRENCY

C<static method SQL_CA2_OPT_ROWVER_CONCURRENCY : int ();>

Returns 4.

=head2 SQL_CA2_OPT_VALUES_CONCURRENCY

C<static method SQL_CA2_OPT_VALUES_CONCURRENCY : int ();>

Returns 8.

=head2 SQL_CA2_READ_ONLY_CONCURRENCY

C<static method SQL_CA2_READ_ONLY_CONCURRENCY : int ();>

Returns 1.

=head2 SQL_CA2_SENSITIVITY_ADDITIONS

C<static method SQL_CA2_SENSITIVITY_ADDITIONS : int ();>

Returns 16.

=head2 SQL_CA2_SENSITIVITY_DELETIONS

C<static method SQL_CA2_SENSITIVITY_DELETIONS : int ();>

Returns 32.

=head2 SQL_CA2_SENSITIVITY_UPDATES

C<static method SQL_CA2_SENSITIVITY_UPDATES : int ();>

Returns 64.

=head2 SQL_CA2_SIMULATE_NON_UNIQUE

C<static method SQL_CA2_SIMULATE_NON_UNIQUE : int ();>

Returns 16384.

=head2 SQL_CA2_SIMULATE_TRY_UNIQUE

C<static method SQL_CA2_SIMULATE_TRY_UNIQUE : int ();>

Returns 32768.

=head2 SQL_CA2_SIMULATE_UNIQUE

C<static method SQL_CA2_SIMULATE_UNIQUE : int ();>

Returns 65536.

=head2 SQL_CA_CONSTRAINT_DEFERRABLE

C<static method SQL_CA_CONSTRAINT_DEFERRABLE : int ();>

Returns 64.

=head2 SQL_CA_CONSTRAINT_INITIALLY_DEFERRED

C<static method SQL_CA_CONSTRAINT_INITIALLY_DEFERRED : int ();>

Returns 16.

=head2 SQL_CA_CONSTRAINT_INITIALLY_IMMEDIATE

C<static method SQL_CA_CONSTRAINT_INITIALLY_IMMEDIATE : int ();>

Returns 32.

=head2 SQL_CA_CONSTRAINT_NON_DEFERRABLE

C<static method SQL_CA_CONSTRAINT_NON_DEFERRABLE : int ();>

Returns 128.

=head2 SQL_CA_CREATE_ASSERTION

C<static method SQL_CA_CREATE_ASSERTION : int ();>

Returns 1.

=head2 SQL_CATALOG_LOCATION

C<static method SQL_CATALOG_LOCATION : int ();>

Returns 114.

=head2 SQL_CATALOG_NAME

C<static method SQL_CATALOG_NAME : int ();>

Returns 10003.

=head2 SQL_CATALOG_NAME_SEPARATOR

C<static method SQL_CATALOG_NAME_SEPARATOR : int ();>

Returns 41.

=head2 SQL_CATALOG_TERM

C<static method SQL_CATALOG_TERM : int ();>

Returns 42.

=head2 SQL_CATALOG_USAGE

C<static method SQL_CATALOG_USAGE : int ();>

Returns 92.

=head2 SQL_CB_CLOSE

C<static method SQL_CB_CLOSE : int ();>

Returns 1.

=head2 SQL_CB_DELETE

C<static method SQL_CB_DELETE : int ();>

Returns 0.

=head2 SQL_CB_NON_NULL

C<static method SQL_CB_NON_NULL : int ();>

Returns 1.

=head2 SQL_CB_NULL

C<static method SQL_CB_NULL : int ();>

Returns 0.

=head2 SQL_CB_PRESERVE

C<static method SQL_CB_PRESERVE : int ();>

Returns 2.

=head2 SQL_CCOL_CREATE_COLLATION

C<static method SQL_CCOL_CREATE_COLLATION : int ();>

Returns 1.

=head2 SQL_CCS_COLLATE_CLAUSE

C<static method SQL_CCS_COLLATE_CLAUSE : int ();>

Returns 2.

=head2 SQL_CCS_CREATE_CHARACTER_SET

C<static method SQL_CCS_CREATE_CHARACTER_SET : int ();>

Returns 1.

=head2 SQL_CCS_LIMITED_COLLATION

C<static method SQL_CCS_LIMITED_COLLATION : int ();>

Returns 4.

=head2 SQL_CDO_COLLATION

C<static method SQL_CDO_COLLATION : int ();>

Returns 8.

=head2 SQL_CDO_CONSTRAINT_DEFERRABLE

C<static method SQL_CDO_CONSTRAINT_DEFERRABLE : int ();>

Returns 128.

=head2 SQL_CDO_CONSTRAINT_INITIALLY_DEFERRED

C<static method SQL_CDO_CONSTRAINT_INITIALLY_DEFERRED : int ();>

Returns 32.

=head2 SQL_CDO_CONSTRAINT_INITIALLY_IMMEDIATE

C<static method SQL_CDO_CONSTRAINT_INITIALLY_IMMEDIATE : int ();>

Returns 64.

=head2 SQL_CDO_CONSTRAINT

C<static method SQL_CDO_CONSTRAINT : int ();>

Returns 4.

=head2 SQL_CDO_CONSTRAINT_NAME_DEFINITION

C<static method SQL_CDO_CONSTRAINT_NAME_DEFINITION : int ();>

Returns 16.

=head2 SQL_CDO_CONSTRAINT_NON_DEFERRABLE

C<static method SQL_CDO_CONSTRAINT_NON_DEFERRABLE : int ();>

Returns 256.

=head2 SQL_CDO_CREATE_DOMAIN

C<static method SQL_CDO_CREATE_DOMAIN : int ();>

Returns 1.

=head2 SQL_CDO_DEFAULT

C<static method SQL_CDO_DEFAULT : int ();>

Returns 2.

=head2 SQL_CL_END

C<static method SQL_CL_END : int ();>

Returns 2.

=head2 SQL_CL_START

C<static method SQL_CL_START : int ();>

Returns 1.

=head2 SQL_CN_ANY

C<static method SQL_CN_ANY : int ();>

Returns 2.

=head2 SQL_CN_DIFFERENT

C<static method SQL_CN_DIFFERENT : int ();>

Returns 1.

=head2 SQL_CN_NONE

C<static method SQL_CN_NONE : int ();>

Returns 0.

=head2 SQL_COLLATING_SEQUENCE

C<static method SQL_COLLATING_SEQUENCE : int ();>

Returns 10004.

=head2 SQL_COLLATION_SEQ

C<static method SQL_COLLATION_SEQ : int ();>

Returns 10004.

=head2 SQL_COLUMN_ALIAS

C<static method SQL_COLUMN_ALIAS : int ();>

Returns 87.

=head2 SQL_CONCAT_NULL_BEHAVIOR

C<static method SQL_CONCAT_NULL_BEHAVIOR : int ();>

Returns 22.

=head2 SQL_CONVERT_BIGINT

C<static method SQL_CONVERT_BIGINT : int ();>

Returns 53.

=head2 SQL_CONVERT_BINARY

C<static method SQL_CONVERT_BINARY : int ();>

Returns 54.

=head2 SQL_CONVERT_BIT

C<static method SQL_CONVERT_BIT : int ();>

Returns 55.

=head2 SQL_CONVERT_CHAR

C<static method SQL_CONVERT_CHAR : int ();>

Returns 56.

=head2 SQL_CONVERT_DATE

C<static method SQL_CONVERT_DATE : int ();>

Returns 57.

=head2 SQL_CONVERT_DECIMAL

C<static method SQL_CONVERT_DECIMAL : int ();>

Returns 58.

=head2 SQL_CONVERT_DOUBLE

C<static method SQL_CONVERT_DOUBLE : int ();>

Returns 59.

=head2 SQL_CONVERT_FLOAT

C<static method SQL_CONVERT_FLOAT : int ();>

Returns 60.

=head2 SQL_CONVERT_FUNCTIONS

C<static method SQL_CONVERT_FUNCTIONS : int ();>

Returns 48.

=head2 SQL_CONVERT_GUID

C<static method SQL_CONVERT_GUID : int ();>

Returns 173.

=head2 SQL_CONVERT_INTEGER

C<static method SQL_CONVERT_INTEGER : int ();>

Returns 61.

=head2 SQL_CONVERT_INTERVAL_DAY_TIME

C<static method SQL_CONVERT_INTERVAL_DAY_TIME : int ();>

Returns 123.

=head2 SQL_CONVERT_INTERVAL_YEAR_MONTH

C<static method SQL_CONVERT_INTERVAL_YEAR_MONTH : int ();>

Returns 124.

=head2 SQL_CONVERT_LONGVARBINARY

C<static method SQL_CONVERT_LONGVARBINARY : int ();>

Returns 71.

=head2 SQL_CONVERT_LONGVARCHAR

C<static method SQL_CONVERT_LONGVARCHAR : int ();>

Returns 62.

=head2 SQL_CONVERT_NUMERIC

C<static method SQL_CONVERT_NUMERIC : int ();>

Returns 63.

=head2 SQL_CONVERT_REAL

C<static method SQL_CONVERT_REAL : int ();>

Returns 64.

=head2 SQL_CONVERT_SMALLINT

C<static method SQL_CONVERT_SMALLINT : int ();>

Returns 65.

=head2 SQL_CONVERT_TIME

C<static method SQL_CONVERT_TIME : int ();>

Returns 66.

=head2 SQL_CONVERT_TIMESTAMP

C<static method SQL_CONVERT_TIMESTAMP : int ();>

Returns 67.

=head2 SQL_CONVERT_TINYINT

C<static method SQL_CONVERT_TINYINT : int ();>

Returns 68.

=head2 SQL_CONVERT_VARBINARY

C<static method SQL_CONVERT_VARBINARY : int ();>

Returns 69.

=head2 SQL_CONVERT_VARCHAR

C<static method SQL_CONVERT_VARCHAR : int ();>

Returns 70.

=head2 SQL_CONVERT_WCHAR

C<static method SQL_CONVERT_WCHAR : int ();>

Returns 122.

=head2 SQL_CONVERT_WLONGVARCHAR

C<static method SQL_CONVERT_WLONGVARCHAR : int ();>

Returns 125.

=head2 SQL_CONVERT_WVARCHAR

C<static method SQL_CONVERT_WVARCHAR : int ();>

Returns 126.

=head2 SQL_CORRELATION_NAME

C<static method SQL_CORRELATION_NAME : int ();>

Returns 74.

=head2 SQL_CREATE_ASSERTION

C<static method SQL_CREATE_ASSERTION : int ();>

Returns 127.

=head2 SQL_CREATE_CHARACTER_SET

C<static method SQL_CREATE_CHARACTER_SET : int ();>

Returns 128.

=head2 SQL_CREATE_COLLATION

C<static method SQL_CREATE_COLLATION : int ();>

Returns 129.

=head2 SQL_CREATE_DOMAIN

C<static method SQL_CREATE_DOMAIN : int ();>

Returns 130.

=head2 SQL_CREATE_SCHEMA

C<static method SQL_CREATE_SCHEMA : int ();>

Returns 131.

=head2 SQL_CREATE_TABLE

C<static method SQL_CREATE_TABLE : int ();>

Returns 132.

=head2 SQL_CREATE_TRANSLATION

C<static method SQL_CREATE_TRANSLATION : int ();>

Returns 133.

=head2 SQL_CREATE_VIEW

C<static method SQL_CREATE_VIEW : int ();>

Returns 134.

=head2 SQL_CS_AUTHORIZATION

C<static method SQL_CS_AUTHORIZATION : int ();>

Returns 2.

=head2 SQL_CS_CREATE_SCHEMA

C<static method SQL_CS_CREATE_SCHEMA : int ();>

Returns 1.

=head2 SQL_CS_DEFAULT_CHARACTER_SET

C<static method SQL_CS_DEFAULT_CHARACTER_SET : int ();>

Returns 4.

=head2 SQL_CT_COLUMN_COLLATION

C<static method SQL_CT_COLUMN_COLLATION : int ();>

Returns 2048.

=head2 SQL_CT_COLUMN_CONSTRAINT

C<static method SQL_CT_COLUMN_CONSTRAINT : int ();>

Returns 512.

=head2 SQL_CT_COLUMN_DEFAULT

C<static method SQL_CT_COLUMN_DEFAULT : int ();>

Returns 1024.

=head2 SQL_CT_COMMIT_DELETE

C<static method SQL_CT_COMMIT_DELETE : int ();>

Returns 4.

=head2 SQL_CT_COMMIT_PRESERVE

C<static method SQL_CT_COMMIT_PRESERVE : int ();>

Returns 2.

=head2 SQL_CT_CONSTRAINT_DEFERRABLE

C<static method SQL_CT_CONSTRAINT_DEFERRABLE : int ();>

Returns 128.

=head2 SQL_CT_CONSTRAINT_INITIALLY_DEFERRED

C<static method SQL_CT_CONSTRAINT_INITIALLY_DEFERRED : int ();>

Returns 32.

=head2 SQL_CT_CONSTRAINT_INITIALLY_IMMEDIATE

C<static method SQL_CT_CONSTRAINT_INITIALLY_IMMEDIATE : int ();>

Returns 64.

=head2 SQL_CT_CONSTRAINT_NAME_DEFINITION

C<static method SQL_CT_CONSTRAINT_NAME_DEFINITION : int ();>

Returns 8192.

=head2 SQL_CT_CONSTRAINT_NON_DEFERRABLE

C<static method SQL_CT_CONSTRAINT_NON_DEFERRABLE : int ();>

Returns 256.

=head2 SQL_CT_CREATE_TABLE

C<static method SQL_CT_CREATE_TABLE : int ();>

Returns 1.

=head2 SQL_CT_GLOBAL_TEMPORARY

C<static method SQL_CT_GLOBAL_TEMPORARY : int ();>

Returns 8.

=head2 SQL_CT_LOCAL_TEMPORARY

C<static method SQL_CT_LOCAL_TEMPORARY : int ();>

Returns 16.

=head2 SQL_CTR_CREATE_TRANSLATION

C<static method SQL_CTR_CREATE_TRANSLATION : int ();>

Returns 1.

=head2 SQL_CT_TABLE_CONSTRAINT

C<static method SQL_CT_TABLE_CONSTRAINT : int ();>

Returns 4096.

=head2 SQL_CU_DML_STATEMENTS

C<static method SQL_CU_DML_STATEMENTS : int ();>

Returns 1.

=head2 SQL_CU_INDEX_DEFINITION

C<static method SQL_CU_INDEX_DEFINITION : int ();>

Returns 8.

=head2 SQL_CU_PRIVILEGE_DEFINITION

C<static method SQL_CU_PRIVILEGE_DEFINITION : int ();>

Returns 16.

=head2 SQL_CU_PROCEDURE_INVOCATION

C<static method SQL_CU_PROCEDURE_INVOCATION : int ();>

Returns 2.

=head2 SQL_CURSOR_COMMIT_BEHAVIOR

C<static method SQL_CURSOR_COMMIT_BEHAVIOR : int ();>

Returns 23.

=head2 SQL_CURSOR_ROLLBACK_BEHAVIOR

C<static method SQL_CURSOR_ROLLBACK_BEHAVIOR : int ();>

Returns 24.

=head2 SQL_CURSOR_SENSITIVITY

C<static method SQL_CURSOR_SENSITIVITY : int ();>

Returns 10001.

=head2 SQL_CU_TABLE_DEFINITION

C<static method SQL_CU_TABLE_DEFINITION : int ();>

Returns 4.

=head2 SQL_CV_CASCADED

C<static method SQL_CV_CASCADED : int ();>

Returns 4.

=head2 SQL_CV_CHECK_OPTION

C<static method SQL_CV_CHECK_OPTION : int ();>

Returns 2.

=head2 SQL_CV_CREATE_VIEW

C<static method SQL_CV_CREATE_VIEW : int ();>

Returns 1.

=head2 SQL_CV_LOCAL

C<static method SQL_CV_LOCAL : int ();>

Returns 8.

=head2 SQL_CVT_BIGINT

C<static method SQL_CVT_BIGINT : int ();>

Returns 16384.

=head2 SQL_CVT_BINARY

C<static method SQL_CVT_BINARY : int ();>

Returns 1024.

=head2 SQL_CVT_BIT

C<static method SQL_CVT_BIT : int ();>

Returns 4096.

=head2 SQL_CVT_CHAR

C<static method SQL_CVT_CHAR : int ();>

Returns 1.

=head2 SQL_CVT_DATE

C<static method SQL_CVT_DATE : int ();>

Returns 32768.

=head2 SQL_CVT_DECIMAL

C<static method SQL_CVT_DECIMAL : int ();>

Returns 4.

=head2 SQL_CVT_DOUBLE

C<static method SQL_CVT_DOUBLE : int ();>

Returns 128.

=head2 SQL_CVT_FLOAT

C<static method SQL_CVT_FLOAT : int ();>

Returns 32.

=head2 SQL_CVT_GUID

C<static method SQL_CVT_GUID : int ();>

Returns 16777216.

=head2 SQL_CVT_INTEGER

C<static method SQL_CVT_INTEGER : int ();>

Returns 8.

=head2 SQL_CVT_INTERVAL_DAY_TIME

C<static method SQL_CVT_INTERVAL_DAY_TIME : int ();>

Returns 1048576.

=head2 SQL_CVT_INTERVAL_YEAR_MONTH

C<static method SQL_CVT_INTERVAL_YEAR_MONTH : int ();>

Returns 524288.

=head2 SQL_CVT_LONGVARBINARY

C<static method SQL_CVT_LONGVARBINARY : int ();>

Returns 262144.

=head2 SQL_CVT_LONGVARCHAR

C<static method SQL_CVT_LONGVARCHAR : int ();>

Returns 512.

=head2 SQL_CVT_NUMERIC

C<static method SQL_CVT_NUMERIC : int ();>

Returns 2.

=head2 SQL_CVT_REAL

C<static method SQL_CVT_REAL : int ();>

Returns 64.

=head2 SQL_CVT_SMALLINT

C<static method SQL_CVT_SMALLINT : int ();>

Returns 16.

=head2 SQL_CVT_TIME

C<static method SQL_CVT_TIME : int ();>

Returns 65536.

=head2 SQL_CVT_TIMESTAMP

C<static method SQL_CVT_TIMESTAMP : int ();>

Returns 131072.

=head2 SQL_CVT_TINYINT

C<static method SQL_CVT_TINYINT : int ();>

Returns 8192.

=head2 SQL_CVT_VARBINARY

C<static method SQL_CVT_VARBINARY : int ();>

Returns 2048.

=head2 SQL_CVT_VARCHAR

C<static method SQL_CVT_VARCHAR : int ();>

Returns 256.

=head2 SQL_CVT_WCHAR

C<static method SQL_CVT_WCHAR : int ();>

Returns 2097152.

=head2 SQL_CVT_WLONGVARCHAR

C<static method SQL_CVT_WLONGVARCHAR : int ();>

Returns 4194304.

=head2 SQL_CVT_WVARCHAR

C<static method SQL_CVT_WVARCHAR : int ();>

Returns 8388608.

=head2 SQL_DA_DROP_ASSERTION

C<static method SQL_DA_DROP_ASSERTION : int ();>

Returns 1.

=head2 SQL_DATABASE_NAME

C<static method SQL_DATABASE_NAME : int ();>

Returns 16.

=head2 SQL_DATA_SOURCE_NAME

C<static method SQL_DATA_SOURCE_NAME : int ();>

Returns 2.

=head2 SQL_DATA_SOURCE_READ_ONLY

C<static method SQL_DATA_SOURCE_READ_ONLY : int ();>

Returns 25.

=head2 SQL_DATETIME_LITERALS

C<static method SQL_DATETIME_LITERALS : int ();>

Returns 119.

=head2 SQL_DBMS_NAME

C<static method SQL_DBMS_NAME : int ();>

Returns 17.

=head2 SQL_DBMS_VER

C<static method SQL_DBMS_VER : int ();>

Returns 18.

=head2 SQL_DBMS_VERSION

C<static method SQL_DBMS_VERSION : int ();>

Returns 18.

=head2 SQL_DC_DROP_COLLATION

C<static method SQL_DC_DROP_COLLATION : int ();>

Returns 1.

=head2 SQL_DCS_DROP_CHARACTER_SET

C<static method SQL_DCS_DROP_CHARACTER_SET : int ();>

Returns 1.

=head2 SQL_DD_CASCADE

C<static method SQL_DD_CASCADE : int ();>

Returns 4.

=head2 SQL_DD_DROP_DOMAIN

C<static method SQL_DD_DROP_DOMAIN : int ();>

Returns 1.

=head2 SQL_DDL_INDEX

C<static method SQL_DDL_INDEX : int ();>

Returns 170.

=head2 SQL_DD_RESTRICT

C<static method SQL_DD_RESTRICT : int ();>

Returns 2.

=head2 SQL_DEFAULT_TRANSACTION_ISOLATION

C<static method SQL_DEFAULT_TRANSACTION_ISOLATION : int ();>

Returns 26.

=head2 SQL_DEFAULT_TXN_ISOLATION

C<static method SQL_DEFAULT_TXN_ISOLATION : int ();>

Returns 26.

=head2 SQL_DESCRIBE_PARAMETER

C<static method SQL_DESCRIBE_PARAMETER : int ();>

Returns 10002.

=head2 SQL_DI_CREATE_INDEX

C<static method SQL_DI_CREATE_INDEX : int ();>

Returns 1.

=head2 SQL_DI_DROP_INDEX

C<static method SQL_DI_DROP_INDEX : int ();>

Returns 2.

=head2 SQL_DL_SQL92_DATE

C<static method SQL_DL_SQL92_DATE : int ();>

Returns 1.

=head2 SQL_DL_SQL92_INTERVAL_DAY

C<static method SQL_DL_SQL92_INTERVAL_DAY : int ();>

Returns 32.

=head2 SQL_DL_SQL92_INTERVAL_DAY_TO_HOUR

C<static method SQL_DL_SQL92_INTERVAL_DAY_TO_HOUR : int ();>

Returns 1024.

=head2 SQL_DL_SQL92_INTERVAL_DAY_TO_MINUTE

C<static method SQL_DL_SQL92_INTERVAL_DAY_TO_MINUTE : int ();>

Returns 2048.

=head2 SQL_DL_SQL92_INTERVAL_DAY_TO_SECOND

C<static method SQL_DL_SQL92_INTERVAL_DAY_TO_SECOND : int ();>

Returns 4096.

=head2 SQL_DL_SQL92_INTERVAL_HOUR

C<static method SQL_DL_SQL92_INTERVAL_HOUR : int ();>

Returns 64.

=head2 SQL_DL_SQL92_INTERVAL_HOUR_TO_MINUTE

C<static method SQL_DL_SQL92_INTERVAL_HOUR_TO_MINUTE : int ();>

Returns 8192.

=head2 SQL_DL_SQL92_INTERVAL_HOUR_TO_SECOND

C<static method SQL_DL_SQL92_INTERVAL_HOUR_TO_SECOND : int ();>

Returns 16384.

=head2 SQL_DL_SQL92_INTERVAL_MINUTE

C<static method SQL_DL_SQL92_INTERVAL_MINUTE : int ();>

Returns 128.

=head2 SQL_DL_SQL92_INTERVAL_MINUTE_TO_SECOND

C<static method SQL_DL_SQL92_INTERVAL_MINUTE_TO_SECOND : int ();>

Returns 32768.

=head2 SQL_DL_SQL92_INTERVAL_MONTH

C<static method SQL_DL_SQL92_INTERVAL_MONTH : int ();>

Returns 16.

=head2 SQL_DL_SQL92_INTERVAL_SECOND

C<static method SQL_DL_SQL92_INTERVAL_SECOND : int ();>

Returns 256.

=head2 SQL_DL_SQL92_INTERVAL_YEAR

C<static method SQL_DL_SQL92_INTERVAL_YEAR : int ();>

Returns 8.

=head2 SQL_DL_SQL92_INTERVAL_YEAR_TO_MONTH

C<static method SQL_DL_SQL92_INTERVAL_YEAR_TO_MONTH : int ();>

Returns 512.

=head2 SQL_DL_SQL92_TIME

C<static method SQL_DL_SQL92_TIME : int ();>

Returns 2.

=head2 SQL_DL_SQL92_TIMESTAMP

C<static method SQL_DL_SQL92_TIMESTAMP : int ();>

Returns 4.

=head2 SQL_DM_VER

C<static method SQL_DM_VER : int ();>

Returns 171.

=head2 SQL_DRIVER_HDBC

C<static method SQL_DRIVER_HDBC : int ();>

Returns 3.

=head2 SQL_DRIVER_HDESC

C<static method SQL_DRIVER_HDESC : int ();>

Returns 135.

=head2 SQL_DRIVER_HENV

C<static method SQL_DRIVER_HENV : int ();>

Returns 4.

=head2 SQL_DRIVER_HLIB

C<static method SQL_DRIVER_HLIB : int ();>

Returns 76.

=head2 SQL_DRIVER_HSTMT

C<static method SQL_DRIVER_HSTMT : int ();>

Returns 5.

=head2 SQL_DRIVER_NAME

C<static method SQL_DRIVER_NAME : int ();>

Returns 6.

=head2 SQL_DRIVER_ODBC_VER

C<static method SQL_DRIVER_ODBC_VER : int ();>

Returns 77.

=head2 SQL_DRIVER_VER

C<static method SQL_DRIVER_VER : int ();>

Returns 7.

=head2 SQL_DROP_ASSERTION

C<static method SQL_DROP_ASSERTION : int ();>

Returns 136.

=head2 SQL_DROP_CHARACTER_SET

C<static method SQL_DROP_CHARACTER_SET : int ();>

Returns 137.

=head2 SQL_DROP_COLLATION

C<static method SQL_DROP_COLLATION : int ();>

Returns 138.

=head2 SQL_DROP_DOMAIN

C<static method SQL_DROP_DOMAIN : int ();>

Returns 139.

=head2 SQL_DROP_SCHEMA

C<static method SQL_DROP_SCHEMA : int ();>

Returns 140.

=head2 SQL_DROP_TABLE

C<static method SQL_DROP_TABLE : int ();>

Returns 141.

=head2 SQL_DROP_TRANSLATION

C<static method SQL_DROP_TRANSLATION : int ();>

Returns 142.

=head2 SQL_DROP_VIEW

C<static method SQL_DROP_VIEW : int ();>

Returns 143.

=head2 SQL_DS_CASCADE

C<static method SQL_DS_CASCADE : int ();>

Returns 4.

=head2 SQL_DS_DROP_SCHEMA

C<static method SQL_DS_DROP_SCHEMA : int ();>

Returns 1.

=head2 SQL_DS_RESTRICT

C<static method SQL_DS_RESTRICT : int ();>

Returns 2.

=head2 SQL_DT_CASCADE

C<static method SQL_DT_CASCADE : int ();>

Returns 4.

=head2 SQL_DT_DROP_TABLE

C<static method SQL_DT_DROP_TABLE : int ();>

Returns 1.

=head2 SQL_DTR_DROP_TRANSLATION

C<static method SQL_DTR_DROP_TRANSLATION : int ();>

Returns 1.

=head2 SQL_DT_RESTRICT

C<static method SQL_DT_RESTRICT : int ();>

Returns 2.

=head2 SQL_DV_CASCADE

C<static method SQL_DV_CASCADE : int ();>

Returns 4.

=head2 SQL_DV_DROP_VIEW

C<static method SQL_DV_DROP_VIEW : int ();>

Returns 1.

=head2 SQL_DV_RESTRICT

C<static method SQL_DV_RESTRICT : int ();>

Returns 2.

=head2 SQL_DYNAMIC_CURSOR_ATTRIBUTES1

C<static method SQL_DYNAMIC_CURSOR_ATTRIBUTES1 : int ();>

Returns 144.

=head2 SQL_DYNAMIC_CURSOR_ATTRIBUTES2

C<static method SQL_DYNAMIC_CURSOR_ATTRIBUTES2 : int ();>

Returns 145.

=head2 SQL_EXPRESSIONS_IN_ORDERBY

C<static method SQL_EXPRESSIONS_IN_ORDERBY : int ();>

Returns 27.

=head2 SQL_FD_FETCH_ABSOLUTE

C<static method SQL_FD_FETCH_ABSOLUTE : int ();>

Returns 16.

=head2 SQL_FD_FETCH_BOOKMARK

C<static method SQL_FD_FETCH_BOOKMARK : int ();>

Returns 128.

=head2 SQL_FD_FETCH_FIRST

C<static method SQL_FD_FETCH_FIRST : int ();>

Returns 2.

=head2 SQL_FD_FETCH_LAST

C<static method SQL_FD_FETCH_LAST : int ();>

Returns 4.

=head2 SQL_FD_FETCH_NEXT

C<static method SQL_FD_FETCH_NEXT : int ();>

Returns 1.

=head2 SQL_FD_FETCH_PRIOR

C<static method SQL_FD_FETCH_PRIOR : int ();>

Returns 8.

=head2 SQL_FD_FETCH_RELATIVE

C<static method SQL_FD_FETCH_RELATIVE : int ();>

Returns 32.

=head2 SQL_FD_FETCH_RESUME

C<static method SQL_FD_FETCH_RESUME : int ();>

Returns 64.

=head2 SQL_FETCH_DIRECTION

C<static method SQL_FETCH_DIRECTION : int ();>

Returns 8.

=head2 SQL_FILE_CATALOG

C<static method SQL_FILE_CATALOG : int ();>

Returns 2.

=head2 SQL_FILE_NOT_SUPPORTED

C<static method SQL_FILE_NOT_SUPPORTED : int ();>

Returns 0.

=head2 SQL_FILE_QUALIFIER

C<static method SQL_FILE_QUALIFIER : int ();>

Returns 2.

=head2 SQL_FILE_TABLE

C<static method SQL_FILE_TABLE : int ();>

Returns 1.

=head2 SQL_FILE_USAGE

C<static method SQL_FILE_USAGE : int ();>

Returns 84.

=head2 SQL_FN_CVT_CAST

C<static method SQL_FN_CVT_CAST : int ();>

Returns 2.

=head2 SQL_FN_CVT_CONVERT

C<static method SQL_FN_CVT_CONVERT : int ();>

Returns 1.

=head2 SQL_FN_NUM_ABS

C<static method SQL_FN_NUM_ABS : int ();>

Returns 1.

=head2 SQL_FN_NUM_ACOS

C<static method SQL_FN_NUM_ACOS : int ();>

Returns 2.

=head2 SQL_FN_NUM_ASIN

C<static method SQL_FN_NUM_ASIN : int ();>

Returns 4.

=head2 SQL_FN_NUM_ATAN2

C<static method SQL_FN_NUM_ATAN2 : int ();>

Returns 16.

=head2 SQL_FN_NUM_ATAN

C<static method SQL_FN_NUM_ATAN : int ();>

Returns 8.

=head2 SQL_FN_NUM_CEILING

C<static method SQL_FN_NUM_CEILING : int ();>

Returns 32.

=head2 SQL_FN_NUM_COS

C<static method SQL_FN_NUM_COS : int ();>

Returns 64.

=head2 SQL_FN_NUM_COT

C<static method SQL_FN_NUM_COT : int ();>

Returns 128.

=head2 SQL_FN_NUM_DEGREES

C<static method SQL_FN_NUM_DEGREES : int ();>

Returns 262144.

=head2 SQL_FN_NUM_EXP

C<static method SQL_FN_NUM_EXP : int ();>

Returns 256.

=head2 SQL_FN_NUM_FLOOR

C<static method SQL_FN_NUM_FLOOR : int ();>

Returns 512.

=head2 SQL_FN_NUM_LOG10

C<static method SQL_FN_NUM_LOG10 : int ();>

Returns 524288.

=head2 SQL_FN_NUM_LOG

C<static method SQL_FN_NUM_LOG : int ();>

Returns 1024.

=head2 SQL_FN_NUM_MOD

C<static method SQL_FN_NUM_MOD : int ();>

Returns 2048.

=head2 SQL_FN_NUM_PI

C<static method SQL_FN_NUM_PI : int ();>

Returns 65536.

=head2 SQL_FN_NUM_POWER

C<static method SQL_FN_NUM_POWER : int ();>

Returns 1048576.

=head2 SQL_FN_NUM_RADIANS

C<static method SQL_FN_NUM_RADIANS : int ();>

Returns 2097152.

=head2 SQL_FN_NUM_RAND

C<static method SQL_FN_NUM_RAND : int ();>

Returns 131072.

=head2 SQL_FN_NUM_ROUND

C<static method SQL_FN_NUM_ROUND : int ();>

Returns 4194304.

=head2 SQL_FN_NUM_SIGN

C<static method SQL_FN_NUM_SIGN : int ();>

Returns 4096.

=head2 SQL_FN_NUM_SIN

C<static method SQL_FN_NUM_SIN : int ();>

Returns 8192.

=head2 SQL_FN_NUM_SQRT

C<static method SQL_FN_NUM_SQRT : int ();>

Returns 16384.

=head2 SQL_FN_NUM_TAN

C<static method SQL_FN_NUM_TAN : int ();>

Returns 32768.

=head2 SQL_FN_NUM_TRUNCATE

C<static method SQL_FN_NUM_TRUNCATE : int ();>

Returns 8388608.

=head2 SQL_FN_STR_ASCII

C<static method SQL_FN_STR_ASCII : int ();>

Returns 8192.

=head2 SQL_FN_STR_BIT_LENGTH

C<static method SQL_FN_STR_BIT_LENGTH : int ();>

Returns 524288.

=head2 SQL_FN_STR_CHARACTER_LENGTH

C<static method SQL_FN_STR_CHARACTER_LENGTH : int ();>

Returns 2097152.

=head2 SQL_FN_STR_CHAR

C<static method SQL_FN_STR_CHAR : int ();>

Returns 16384.

=head2 SQL_FN_STR_CHAR_LENGTH

C<static method SQL_FN_STR_CHAR_LENGTH : int ();>

Returns 1048576.

=head2 SQL_FN_STR_CONCAT

C<static method SQL_FN_STR_CONCAT : int ();>

Returns 1.

=head2 SQL_FN_STR_DIFFERENCE

C<static method SQL_FN_STR_DIFFERENCE : int ();>

Returns 32768.

=head2 SQL_FN_STR_INSERT

C<static method SQL_FN_STR_INSERT : int ();>

Returns 2.

=head2 SQL_FN_STR_LCASE

C<static method SQL_FN_STR_LCASE : int ();>

Returns 64.

=head2 SQL_FN_STR_LEFT

C<static method SQL_FN_STR_LEFT : int ();>

Returns 4.

=head2 SQL_FN_STR_LENGTH

C<static method SQL_FN_STR_LENGTH : int ();>

Returns 16.

=head2 SQL_FN_STR_LOCATE_2

C<static method SQL_FN_STR_LOCATE_2 : int ();>

Returns 65536.

=head2 SQL_FN_STR_LOCATE

C<static method SQL_FN_STR_LOCATE : int ();>

Returns 32.

=head2 SQL_FN_STR_LTRIM

C<static method SQL_FN_STR_LTRIM : int ();>

Returns 8.

=head2 SQL_FN_STR_OCTET_LENGTH

C<static method SQL_FN_STR_OCTET_LENGTH : int ();>

Returns 4194304.

=head2 SQL_FN_STR_POSITION

C<static method SQL_FN_STR_POSITION : int ();>

Returns 8388608.

=head2 SQL_FN_STR_REPEAT

C<static method SQL_FN_STR_REPEAT : int ();>

Returns 128.

=head2 SQL_FN_STR_REPLACE

C<static method SQL_FN_STR_REPLACE : int ();>

Returns 256.

=head2 SQL_FN_STR_RIGHT

C<static method SQL_FN_STR_RIGHT : int ();>

Returns 512.

=head2 SQL_FN_STR_RTRIM

C<static method SQL_FN_STR_RTRIM : int ();>

Returns 1024.

=head2 SQL_FN_STR_SOUNDEX

C<static method SQL_FN_STR_SOUNDEX : int ();>

Returns 131072.

=head2 SQL_FN_STR_SPACE

C<static method SQL_FN_STR_SPACE : int ();>

Returns 262144.

=head2 SQL_FN_STR_SUBSTRING

C<static method SQL_FN_STR_SUBSTRING : int ();>

Returns 2048.

=head2 SQL_FN_STR_UCASE

C<static method SQL_FN_STR_UCASE : int ();>

Returns 4096.

=head2 SQL_FN_SYS_DBNAME

C<static method SQL_FN_SYS_DBNAME : int ();>

Returns 2.

=head2 SQL_FN_SYS_IFNULL

C<static method SQL_FN_SYS_IFNULL : int ();>

Returns 4.

=head2 SQL_FN_SYS_USERNAME

C<static method SQL_FN_SYS_USERNAME : int ();>

Returns 1.

=head2 SQL_FN_TD_CURDATE

C<static method SQL_FN_TD_CURDATE : int ();>

Returns 2.

=head2 SQL_FN_TD_CURRENT_DATE

C<static method SQL_FN_TD_CURRENT_DATE : int ();>

Returns 131072.

=head2 SQL_FN_TD_CURRENT_TIME

C<static method SQL_FN_TD_CURRENT_TIME : int ();>

Returns 262144.

=head2 SQL_FN_TD_CURRENT_TIMESTAMP

C<static method SQL_FN_TD_CURRENT_TIMESTAMP : int ();>

Returns 524288.

=head2 SQL_FN_TD_CURTIME

C<static method SQL_FN_TD_CURTIME : int ();>

Returns 512.

=head2 SQL_FN_TD_DAYNAME

C<static method SQL_FN_TD_DAYNAME : int ();>

Returns 32768.

=head2 SQL_FN_TD_DAYOFMONTH

C<static method SQL_FN_TD_DAYOFMONTH : int ();>

Returns 4.

=head2 SQL_FN_TD_DAYOFWEEK

C<static method SQL_FN_TD_DAYOFWEEK : int ();>

Returns 8.

=head2 SQL_FN_TD_DAYOFYEAR

C<static method SQL_FN_TD_DAYOFYEAR : int ();>

Returns 16.

=head2 SQL_FN_TD_EXTRACT

C<static method SQL_FN_TD_EXTRACT : int ();>

Returns 1048576.

=head2 SQL_FN_TD_HOUR

C<static method SQL_FN_TD_HOUR : int ();>

Returns 1024.

=head2 SQL_FN_TD_MINUTE

C<static method SQL_FN_TD_MINUTE : int ();>

Returns 2048.

=head2 SQL_FN_TD_MONTH

C<static method SQL_FN_TD_MONTH : int ();>

Returns 32.

=head2 SQL_FN_TD_MONTHNAME

C<static method SQL_FN_TD_MONTHNAME : int ();>

Returns 65536.

=head2 SQL_FN_TD_NOW

C<static method SQL_FN_TD_NOW : int ();>

Returns 1.

=head2 SQL_FN_TD_QUARTER

C<static method SQL_FN_TD_QUARTER : int ();>

Returns 64.

=head2 SQL_FN_TD_SECOND

C<static method SQL_FN_TD_SECOND : int ();>

Returns 4096.

=head2 SQL_FN_TD_TIMESTAMPADD

C<static method SQL_FN_TD_TIMESTAMPADD : int ();>

Returns 8192.

=head2 SQL_FN_TD_TIMESTAMPDIFF

C<static method SQL_FN_TD_TIMESTAMPDIFF : int ();>

Returns 16384.

=head2 SQL_FN_TD_WEEK

C<static method SQL_FN_TD_WEEK : int ();>

Returns 128.

=head2 SQL_FN_TD_YEAR

C<static method SQL_FN_TD_YEAR : int ();>

Returns 256.

=head2 SQL_FN_TSI_DAY

C<static method SQL_FN_TSI_DAY : int ();>

Returns 16.

=head2 SQL_FN_TSI_FRAC_SECOND

C<static method SQL_FN_TSI_FRAC_SECOND : int ();>

Returns 1.

=head2 SQL_FN_TSI_HOUR

C<static method SQL_FN_TSI_HOUR : int ();>

Returns 8.

=head2 SQL_FN_TSI_MINUTE

C<static method SQL_FN_TSI_MINUTE : int ();>

Returns 4.

=head2 SQL_FN_TSI_MONTH

C<static method SQL_FN_TSI_MONTH : int ();>

Returns 64.

=head2 SQL_FN_TSI_QUARTER

C<static method SQL_FN_TSI_QUARTER : int ();>

Returns 128.

=head2 SQL_FN_TSI_SECOND

C<static method SQL_FN_TSI_SECOND : int ();>

Returns 2.

=head2 SQL_FN_TSI_WEEK

C<static method SQL_FN_TSI_WEEK : int ();>

Returns 32.

=head2 SQL_FN_TSI_YEAR

C<static method SQL_FN_TSI_YEAR : int ();>

Returns 256.

=head2 SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1

C<static method SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1 : int ();>

Returns 146.

=head2 SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2

C<static method SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2 : int ();>

Returns 147.

=head2 SQL_GB_COLLATE

C<static method SQL_GB_COLLATE : int ();>

Returns 4.

=head2 SQL_GB_GROUP_BY_CONTAINS_SELECT

C<static method SQL_GB_GROUP_BY_CONTAINS_SELECT : int ();>

Returns 2.

=head2 SQL_GB_GROUP_BY_EQUALS_SELECT

C<static method SQL_GB_GROUP_BY_EQUALS_SELECT : int ();>

Returns 1.

=head2 SQL_GB_NO_RELATION

C<static method SQL_GB_NO_RELATION : int ();>

Returns 3.

=head2 SQL_GB_NOT_SUPPORTED

C<static method SQL_GB_NOT_SUPPORTED : int ();>

Returns 0.

=head2 SQL_GD_ANY_COLUMN

C<static method SQL_GD_ANY_COLUMN : int ();>

Returns 1.

=head2 SQL_GD_ANY_ORDER

C<static method SQL_GD_ANY_ORDER : int ();>

Returns 2.

=head2 SQL_GD_BLOCK

C<static method SQL_GD_BLOCK : int ();>

Returns 4.

=head2 SQL_GD_BOUND

C<static method SQL_GD_BOUND : int ();>

Returns 8.

=head2 SQL_GETDATA_EXTENSIONS

C<static method SQL_GETDATA_EXTENSIONS : int ();>

Returns 81.

=head2 SQL_GROUP_BY

C<static method SQL_GROUP_BY : int ();>

Returns 88.

=head2 SQL_IC_LOWER

C<static method SQL_IC_LOWER : int ();>

Returns 2.

=head2 SQL_IC_MIXED

C<static method SQL_IC_MIXED : int ();>

Returns 4.

=head2 SQL_IC_SENSITIVE

C<static method SQL_IC_SENSITIVE : int ();>

Returns 3.

=head2 SQL_IC_UPPER

C<static method SQL_IC_UPPER : int ();>

Returns 1.

=head2 SQL_IDENTIFIER_CASE

C<static method SQL_IDENTIFIER_CASE : int ();>

Returns 28.

=head2 SQL_IDENTIFIER_QUOTE_CHAR

C<static method SQL_IDENTIFIER_QUOTE_CHAR : int ();>

Returns 29.

=head2 SQL_IK_ASC

C<static method SQL_IK_ASC : int ();>

Returns 1.

=head2 SQL_IK_DESC

C<static method SQL_IK_DESC : int ();>

Returns 2.

=head2 SQL_IK_NONE

C<static method SQL_IK_NONE : int ();>

Returns 0.

=head2 SQL_INDEX_KEYWORDS

C<static method SQL_INDEX_KEYWORDS : int ();>

Returns 148.

=head2 SQL_INFO_SCHEMA_VIEWS

C<static method SQL_INFO_SCHEMA_VIEWS : int ();>

Returns 149.

=head2 SQL_INSENSITIVE

C<static method SQL_INSENSITIVE : int ();>

Returns 1.

=head2 SQL_INSERT_STATEMENT

C<static method SQL_INSERT_STATEMENT : int ();>

Returns 172.

=head2 SQL_INTEGRITY

C<static method SQL_INTEGRITY : int ();>

Returns 73.

=head2 SQL_IS_INSERT_LITERALS

C<static method SQL_IS_INSERT_LITERALS : int ();>

Returns 1.

=head2 SQL_IS_INSERT_SEARCHED

C<static method SQL_IS_INSERT_SEARCHED : int ();>

Returns 2.

=head2 SQL_IS_SELECT_INTO

C<static method SQL_IS_SELECT_INTO : int ();>

Returns 4.

=head2 SQL_ISV_ASSERTIONS

C<static method SQL_ISV_ASSERTIONS : int ();>

Returns 1.

=head2 SQL_ISV_CHARACTER_SETS

C<static method SQL_ISV_CHARACTER_SETS : int ();>

Returns 2.

=head2 SQL_ISV_CHECK_CONSTRAINTS

C<static method SQL_ISV_CHECK_CONSTRAINTS : int ();>

Returns 4.

=head2 SQL_ISV_COLLATIONS

C<static method SQL_ISV_COLLATIONS : int ();>

Returns 8.

=head2 SQL_ISV_COLUMN_DOMAIN_USAGE

C<static method SQL_ISV_COLUMN_DOMAIN_USAGE : int ();>

Returns 16.

=head2 SQL_ISV_COLUMN_PRIVILEGES

C<static method SQL_ISV_COLUMN_PRIVILEGES : int ();>

Returns 32.

=head2 SQL_ISV_COLUMNS

C<static method SQL_ISV_COLUMNS : int ();>

Returns 64.

=head2 SQL_ISV_CONSTRAINT_COLUMN_USAGE

C<static method SQL_ISV_CONSTRAINT_COLUMN_USAGE : int ();>

Returns 128.

=head2 SQL_ISV_CONSTRAINT_TABLE_USAGE

C<static method SQL_ISV_CONSTRAINT_TABLE_USAGE : int ();>

Returns 256.

=head2 SQL_ISV_DOMAIN_CONSTRAINTS

C<static method SQL_ISV_DOMAIN_CONSTRAINTS : int ();>

Returns 512.

=head2 SQL_ISV_DOMAINS

C<static method SQL_ISV_DOMAINS : int ();>

Returns 1024.

=head2 SQL_ISV_KEY_COLUMN_USAGE

C<static method SQL_ISV_KEY_COLUMN_USAGE : int ();>

Returns 2048.

=head2 SQL_ISV_REFERENTIAL_CONSTRAINTS

C<static method SQL_ISV_REFERENTIAL_CONSTRAINTS : int ();>

Returns 4096.

=head2 SQL_ISV_SCHEMATA

C<static method SQL_ISV_SCHEMATA : int ();>

Returns 8192.

=head2 SQL_ISV_SQL_LANGUAGES

C<static method SQL_ISV_SQL_LANGUAGES : int ();>

Returns 16384.

=head2 SQL_ISV_TABLE_CONSTRAINTS

C<static method SQL_ISV_TABLE_CONSTRAINTS : int ();>

Returns 32768.

=head2 SQL_ISV_TABLE_PRIVILEGES

C<static method SQL_ISV_TABLE_PRIVILEGES : int ();>

Returns 65536.

=head2 SQL_ISV_TABLES

C<static method SQL_ISV_TABLES : int ();>

Returns 131072.

=head2 SQL_ISV_TRANSLATIONS

C<static method SQL_ISV_TRANSLATIONS : int ();>

Returns 262144.

=head2 SQL_ISV_USAGE_PRIVILEGES

C<static method SQL_ISV_USAGE_PRIVILEGES : int ();>

Returns 524288.

=head2 SQL_ISV_VIEW_COLUMN_USAGE

C<static method SQL_ISV_VIEW_COLUMN_USAGE : int ();>

Returns 1048576.

=head2 SQL_ISV_VIEWS

C<static method SQL_ISV_VIEWS : int ();>

Returns 4194304.

=head2 SQL_ISV_VIEW_TABLE_USAGE

C<static method SQL_ISV_VIEW_TABLE_USAGE : int ();>

Returns 2097152.

=head2 SQL_KEYSET_CURSOR_ATTRIBUTES1

C<static method SQL_KEYSET_CURSOR_ATTRIBUTES1 : int ();>

Returns 150.

=head2 SQL_KEYSET_CURSOR_ATTRIBUTES2

C<static method SQL_KEYSET_CURSOR_ATTRIBUTES2 : int ();>

Returns 151.

=head2 SQL_KEYWORDS

C<static method SQL_KEYWORDS : int ();>

Returns 89.

=head2 SQL_LCK_EXCLUSIVE

C<static method SQL_LCK_EXCLUSIVE : int ();>

Returns 2.

=head2 SQL_LCK_NO_CHANGE

C<static method SQL_LCK_NO_CHANGE : int ();>

Returns 1.

=head2 SQL_LCK_UNLOCK

C<static method SQL_LCK_UNLOCK : int ();>

Returns 4.

=head2 SQL_LIKE_ESCAPE_CLAUSE

C<static method SQL_LIKE_ESCAPE_CLAUSE : int ();>

Returns 113.

=head2 SQL_LOCK_TYPES

C<static method SQL_LOCK_TYPES : int ();>

Returns 78.

=head2 SQL_MAX_ASYNC_CONCURRENT_STATEMENTS

C<static method SQL_MAX_ASYNC_CONCURRENT_STATEMENTS : int ();>

Returns 10022.

=head2 SQL_MAX_BINARY_LITERAL_LEN

C<static method SQL_MAX_BINARY_LITERAL_LEN : int ();>

Returns 112.

=head2 SQL_MAX_CATALOG_NAME_LEN

C<static method SQL_MAX_CATALOG_NAME_LEN : int ();>

Returns 34.

=head2 SQL_MAX_CHAR_LITERAL_LEN

C<static method SQL_MAX_CHAR_LITERAL_LEN : int ();>

Returns 108.

=head2 SQL_MAX_COLUMN_NAME_LEN

C<static method SQL_MAX_COLUMN_NAME_LEN : int ();>

Returns 30.

=head2 SQL_MAX_COLUMNS_IN_GROUP_BY

C<static method SQL_MAX_COLUMNS_IN_GROUP_BY : int ();>

Returns 97.

=head2 SQL_MAX_COLUMNS_IN_INDEX

C<static method SQL_MAX_COLUMNS_IN_INDEX : int ();>

Returns 98.

=head2 SQL_MAX_COLUMNS_IN_ORDER_BY

C<static method SQL_MAX_COLUMNS_IN_ORDER_BY : int ();>

Returns 99.

=head2 SQL_MAX_COLUMNS_IN_SELECT

C<static method SQL_MAX_COLUMNS_IN_SELECT : int ();>

Returns 100.

=head2 SQL_MAX_COLUMNS_IN_TABLE

C<static method SQL_MAX_COLUMNS_IN_TABLE : int ();>

Returns 101.

=head2 SQL_MAX_CONCURRENT_ACTIVITIES

C<static method SQL_MAX_CONCURRENT_ACTIVITIES : int ();>

Returns 1.

=head2 SQL_MAX_CURSOR_NAME_LEN

C<static method SQL_MAX_CURSOR_NAME_LEN : int ();>

Returns 31.

=head2 SQL_MAX_DRIVER_CONNECTIONS

C<static method SQL_MAX_DRIVER_CONNECTIONS : int ();>

Returns 0.

=head2 SQL_MAX_IDENTIFIER_LEN

C<static method SQL_MAX_IDENTIFIER_LEN : int ();>

Returns 10005.

=head2 SQL_MAXIMUM_CATALOG_NAME_LENGTH

C<static method SQL_MAXIMUM_CATALOG_NAME_LENGTH : int ();>

Returns 34.

=head2 SQL_MAXIMUM_COLUMN_NAME_LENGTH

C<static method SQL_MAXIMUM_COLUMN_NAME_LENGTH : int ();>

Returns 30.

=head2 SQL_MAXIMUM_COLUMNS_IN_GROUP_BY

C<static method SQL_MAXIMUM_COLUMNS_IN_GROUP_BY : int ();>

Returns 97.

=head2 SQL_MAXIMUM_COLUMNS_IN_INDEX

C<static method SQL_MAXIMUM_COLUMNS_IN_INDEX : int ();>

Returns 98.

=head2 SQL_MAXIMUM_COLUMNS_IN_ORDER_BY

C<static method SQL_MAXIMUM_COLUMNS_IN_ORDER_BY : int ();>

Returns 99.

=head2 SQL_MAXIMUM_COLUMNS_IN_SELECT

C<static method SQL_MAXIMUM_COLUMNS_IN_SELECT : int ();>

Returns 100.

=head2 SQL_MAXIMUM_COLUMNS_IN_TABLE

C<static method SQL_MAXIMUM_COLUMNS_IN_TABLE : int ();>

Returns 101.

=head2 SQL_MAXIMUM_CONCURRENT_ACTIVITIES

C<static method SQL_MAXIMUM_CONCURRENT_ACTIVITIES : int ();>

Returns 1.

=head2 SQL_MAXIMUM_CURSOR_NAME_LENGTH

C<static method SQL_MAXIMUM_CURSOR_NAME_LENGTH : int ();>

Returns 31.

=head2 SQL_MAXIMUM_DRIVER_CONNECTIONS

C<static method SQL_MAXIMUM_DRIVER_CONNECTIONS : int ();>

Returns 0.

=head2 SQL_MAXIMUM_IDENTIFIER_LENGTH

C<static method SQL_MAXIMUM_IDENTIFIER_LENGTH : int ();>

Returns 10005.

=head2 SQL_MAXIMUM_INDEX_SIZE

C<static method SQL_MAXIMUM_INDEX_SIZE : int ();>

Returns 102.

=head2 SQL_MAXIMUM_ROW_SIZE

C<static method SQL_MAXIMUM_ROW_SIZE : int ();>

Returns 104.

=head2 SQL_MAXIMUM_SCHEMA_NAME_LENGTH

C<static method SQL_MAXIMUM_SCHEMA_NAME_LENGTH : int ();>

Returns 32.

=head2 SQL_MAXIMUM_STATEMENT_LENGTH

C<static method SQL_MAXIMUM_STATEMENT_LENGTH : int ();>

Returns 105.

=head2 SQL_MAXIMUM_STMT_OCTETS_DATA

C<static method SQL_MAXIMUM_STMT_OCTETS_DATA : int ();>

Returns 20001.

=head2 SQL_MAXIMUM_STMT_OCTETS

C<static method SQL_MAXIMUM_STMT_OCTETS : int ();>

Returns 20000.

=head2 SQL_MAXIMUM_STMT_OCTETS_SCHEMA

C<static method SQL_MAXIMUM_STMT_OCTETS_SCHEMA : int ();>

Returns 20002.

=head2 SQL_MAXIMUM_TABLE_NAME_LENGTH

C<static method SQL_MAXIMUM_TABLE_NAME_LENGTH : int ();>

Returns 35.

=head2 SQL_MAXIMUM_TABLES_IN_SELECT

C<static method SQL_MAXIMUM_TABLES_IN_SELECT : int ();>

Returns 106.

=head2 SQL_MAXIMUM_USER_NAME_LENGTH

C<static method SQL_MAXIMUM_USER_NAME_LENGTH : int ();>

Returns 107.

=head2 SQL_MAX_INDEX_SIZE

C<static method SQL_MAX_INDEX_SIZE : int ();>

Returns 102.

=head2 SQL_MAX_OWNER_NAME_LEN

C<static method SQL_MAX_OWNER_NAME_LEN : int ();>

Returns 32.

=head2 SQL_MAX_PROCEDURE_NAME_LEN

C<static method SQL_MAX_PROCEDURE_NAME_LEN : int ();>

Returns 33.

=head2 SQL_MAX_QUALIFIER_NAME_LEN

C<static method SQL_MAX_QUALIFIER_NAME_LEN : int ();>

Returns 34.

=head2 SQL_MAX_ROW_SIZE_INCLUDES_LONG

C<static method SQL_MAX_ROW_SIZE_INCLUDES_LONG : int ();>

Returns 103.

=head2 SQL_MAX_ROW_SIZE

C<static method SQL_MAX_ROW_SIZE : int ();>

Returns 104.

=head2 SQL_MAX_SCHEMA_NAME_LEN

C<static method SQL_MAX_SCHEMA_NAME_LEN : int ();>

Returns 32.

=head2 SQL_MAX_STATEMENT_LEN

C<static method SQL_MAX_STATEMENT_LEN : int ();>

Returns 105.

=head2 SQL_MAX_TABLE_NAME_LEN

C<static method SQL_MAX_TABLE_NAME_LEN : int ();>

Returns 35.

=head2 SQL_MAX_TABLES_IN_SELECT

C<static method SQL_MAX_TABLES_IN_SELECT : int ();>

Returns 106.

=head2 SQL_MAX_USER_NAME_LEN

C<static method SQL_MAX_USER_NAME_LEN : int ();>

Returns 107.

=head2 SQL_MULTIPLE_ACTIVE_TXN

C<static method SQL_MULTIPLE_ACTIVE_TXN : int ();>

Returns 37.

=head2 SQL_MULT_RESULT_SETS

C<static method SQL_MULT_RESULT_SETS : int ();>

Returns 36.

=head2 SQL_NC_END

C<static method SQL_NC_END : int ();>

Returns 4.

=head2 SQL_NC_HIGH

C<static method SQL_NC_HIGH : int ();>

Returns 0.

=head2 SQL_NC_LOW

C<static method SQL_NC_LOW : int ();>

Returns 1.

=head2 SQL_NC_START

C<static method SQL_NC_START : int ();>

Returns 2.

=head2 SQL_NEED_LONG_DATA_LEN

C<static method SQL_NEED_LONG_DATA_LEN : int ();>

Returns 111.

=head2 SQL_NNC_NON_NULL

C<static method SQL_NNC_NON_NULL : int ();>

Returns 1.

=head2 SQL_NNC_NULL

C<static method SQL_NNC_NULL : int ();>

Returns 0.

=head2 SQL_NON_NULLABLE_COLUMNS

C<static method SQL_NON_NULLABLE_COLUMNS : int ();>

Returns 75.

=head2 SQL_NULL_COLLATION

C<static method SQL_NULL_COLLATION : int ();>

Returns 85.

=head2 SQL_NUMERIC_FUNCTIONS

C<static method SQL_NUMERIC_FUNCTIONS : int ();>

Returns 49.

=head2 SQL_OAC_LEVEL1

C<static method SQL_OAC_LEVEL1 : int ();>

Returns 1.

=head2 SQL_OAC_LEVEL2

C<static method SQL_OAC_LEVEL2 : int ();>

Returns 2.

=head2 SQL_OAC_NONE

C<static method SQL_OAC_NONE : int ();>

Returns 0.

=head2 SQL_ODBC_API_CONFORMANCE

C<static method SQL_ODBC_API_CONFORMANCE : int ();>

Returns 9.

=head2 SQL_ODBC_INTERFACE_CONFORMANCE

C<static method SQL_ODBC_INTERFACE_CONFORMANCE : int ();>

Returns 152.

=head2 SQL_ODBC_SAG_CLI_CONFORMANCE

C<static method SQL_ODBC_SAG_CLI_CONFORMANCE : int ();>

Returns 12.

=head2 SQL_ODBC_SQL_CONFORMANCE

C<static method SQL_ODBC_SQL_CONFORMANCE : int ();>

Returns 15.

=head2 SQL_ODBC_SQL_OPT_IEF

C<static method SQL_ODBC_SQL_OPT_IEF : int ();>

Returns 73.

=head2 SQL_ODBC_VER

C<static method SQL_ODBC_VER : int ();>

Returns 10.

=head2 SQL_OIC_CORE

C<static method SQL_OIC_CORE : int ();>

Returns 1.

=head2 SQL_OIC_LEVEL1

C<static method SQL_OIC_LEVEL1 : int ();>

Returns 2.

=head2 SQL_OIC_LEVEL2

C<static method SQL_OIC_LEVEL2 : int ();>

Returns 3.

=head2 SQL_OJ_ALL_COMPARISON_OPS

C<static method SQL_OJ_ALL_COMPARISON_OPS : int ();>

Returns 64.

=head2 SQL_OJ_CAPABILITIES

C<static method SQL_OJ_CAPABILITIES : int ();>

Returns 115.

=head2 SQL_OJ_FULL

C<static method SQL_OJ_FULL : int ();>

Returns 4.

=head2 SQL_OJ_INNER

C<static method SQL_OJ_INNER : int ();>

Returns 32.

=head2 SQL_OJ_LEFT

C<static method SQL_OJ_LEFT : int ();>

Returns 1.

=head2 SQL_OJ_NESTED

C<static method SQL_OJ_NESTED : int ();>

Returns 8.

=head2 SQL_OJ_NOT_ORDERED

C<static method SQL_OJ_NOT_ORDERED : int ();>

Returns 16.

=head2 SQL_OJ_RIGHT

C<static method SQL_OJ_RIGHT : int ();>

Returns 2.

=head2 SQL_ORDER_BY_COLUMNS_IN_SELECT

C<static method SQL_ORDER_BY_COLUMNS_IN_SELECT : int ();>

Returns 90.

=head2 SQL_OSCC_COMPLIANT

C<static method SQL_OSCC_COMPLIANT : int ();>

Returns 1.

=head2 SQL_OSCC_NOT_COMPLIANT

C<static method SQL_OSCC_NOT_COMPLIANT : int ();>

Returns 0.

=head2 SQL_OSC_CORE

C<static method SQL_OSC_CORE : int ();>

Returns 1.

=head2 SQL_OSC_EXTENDED

C<static method SQL_OSC_EXTENDED : int ();>

Returns 2.

=head2 SQL_OSC_MINIMUM

C<static method SQL_OSC_MINIMUM : int ();>

Returns 0.

=head2 SQL_OU_DML_STATEMENTS

C<static method SQL_OU_DML_STATEMENTS : int ();>

Returns 1.

=head2 SQL_OU_INDEX_DEFINITION

C<static method SQL_OU_INDEX_DEFINITION : int ();>

Returns 8.

=head2 SQL_OU_PRIVILEGE_DEFINITION

C<static method SQL_OU_PRIVILEGE_DEFINITION : int ();>

Returns 16.

=head2 SQL_OU_PROCEDURE_INVOCATION

C<static method SQL_OU_PROCEDURE_INVOCATION : int ();>

Returns 2.

=head2 SQL_OU_TABLE_DEFINITION

C<static method SQL_OU_TABLE_DEFINITION : int ();>

Returns 4.

=head2 SQL_OUTER_JOIN_ALL_COMPARISON_OPS

C<static method SQL_OUTER_JOIN_ALL_COMPARISON_OPS : int ();>

Returns 64.

=head2 SQL_OUTER_JOIN_CAPABILITIES

C<static method SQL_OUTER_JOIN_CAPABILITIES : int ();>

Returns 115.

=head2 SQL_OUTER_JOIN_FULL

C<static method SQL_OUTER_JOIN_FULL : int ();>

Returns 4.

=head2 SQL_OUTER_JOIN_INNER

C<static method SQL_OUTER_JOIN_INNER : int ();>

Returns 32.

=head2 SQL_OUTER_JOIN_LEFT

C<static method SQL_OUTER_JOIN_LEFT : int ();>

Returns 1.

=head2 SQL_OUTER_JOIN_NESTED

C<static method SQL_OUTER_JOIN_NESTED : int ();>

Returns 8.

=head2 SQL_OUTER_JOIN_NOT_ORDERED

C<static method SQL_OUTER_JOIN_NOT_ORDERED : int ();>

Returns 16.

=head2 SQL_OUTER_JOIN_RIGHT

C<static method SQL_OUTER_JOIN_RIGHT : int ();>

Returns 2.

=head2 SQL_OUTER_JOINS

C<static method SQL_OUTER_JOINS : int ();>

Returns 38.

=head2 SQL_OWNER_TERM

C<static method SQL_OWNER_TERM : int ();>

Returns 39.

=head2 SQL_OWNER_USAGE

C<static method SQL_OWNER_USAGE : int ();>

Returns 91.

=head2 SQL_PARAM_ARRAY_ROW_COUNTS

C<static method SQL_PARAM_ARRAY_ROW_COUNTS : int ();>

Returns 153.

=head2 SQL_PARAM_ARRAY_SELECTS

C<static method SQL_PARAM_ARRAY_SELECTS : int ();>

Returns 154.

=head2 SQL_PARC_BATCH

C<static method SQL_PARC_BATCH : int ();>

Returns 1.

=head2 SQL_PARC_NO_BATCH

C<static method SQL_PARC_NO_BATCH : int ();>

Returns 2.

=head2 SQL_PAS_BATCH

C<static method SQL_PAS_BATCH : int ();>

Returns 1.

=head2 SQL_PAS_NO_BATCH

C<static method SQL_PAS_NO_BATCH : int ();>

Returns 2.

=head2 SQL_PAS_NO_SELECT

C<static method SQL_PAS_NO_SELECT : int ();>

Returns 3.

=head2 SQL_POS_ADD

C<static method SQL_POS_ADD : int ();>

Returns 16.

=head2 SQL_POS_DELETE

C<static method SQL_POS_DELETE : int ();>

Returns 8.

=head2 SQL_POSITIONED_STATEMENTS

C<static method SQL_POSITIONED_STATEMENTS : int ();>

Returns 80.

=head2 SQL_POS_OPERATIONS

C<static method SQL_POS_OPERATIONS : int ();>

Returns 79.

=head2 SQL_POS_POSITION

C<static method SQL_POS_POSITION : int ();>

Returns 1.

=head2 SQL_POS_REFRESH

C<static method SQL_POS_REFRESH : int ();>

Returns 2.

=head2 SQL_POS_UPDATE

C<static method SQL_POS_UPDATE : int ();>

Returns 4.

=head2 SQL_PROCEDURES

C<static method SQL_PROCEDURES : int ();>

Returns 21.

=head2 SQL_PROCEDURE_TERM

C<static method SQL_PROCEDURE_TERM : int ();>

Returns 40.

=head2 SQL_PS_POSITIONED_DELETE

C<static method SQL_PS_POSITIONED_DELETE : int ();>

Returns 1.

=head2 SQL_PS_POSITIONED_UPDATE

C<static method SQL_PS_POSITIONED_UPDATE : int ();>

Returns 2.

=head2 SQL_PS_SELECT_FOR_UPDATE

C<static method SQL_PS_SELECT_FOR_UPDATE : int ();>

Returns 4.

=head2 SQL_QL_END

C<static method SQL_QL_END : int ();>

Returns 2.

=head2 SQL_QL_START

C<static method SQL_QL_START : int ();>

Returns 1.

=head2 SQL_QUALIFIER_LOCATION

C<static method SQL_QUALIFIER_LOCATION : int ();>

Returns 114.

=head2 SQL_QUALIFIER_NAME_SEPARATOR

C<static method SQL_QUALIFIER_NAME_SEPARATOR : int ();>

Returns 41.

=head2 SQL_QUALIFIER_TERM

C<static method SQL_QUALIFIER_TERM : int ();>

Returns 42.

=head2 SQL_QUALIFIER_USAGE

C<static method SQL_QUALIFIER_USAGE : int ();>

Returns 92.

=head2 SQL_QU_DML_STATEMENTS

C<static method SQL_QU_DML_STATEMENTS : int ();>

Returns 1.

=head2 SQL_QU_INDEX_DEFINITION

C<static method SQL_QU_INDEX_DEFINITION : int ();>

Returns 8.

=head2 SQL_QUOTED_IDENTIFIER_CASE

C<static method SQL_QUOTED_IDENTIFIER_CASE : int ();>

Returns 93.

=head2 SQL_QU_PRIVILEGE_DEFINITION

C<static method SQL_QU_PRIVILEGE_DEFINITION : int ();>

Returns 16.

=head2 SQL_QU_PROCEDURE_INVOCATION

C<static method SQL_QU_PROCEDURE_INVOCATION : int ();>

Returns 2.

=head2 SQL_QU_TABLE_DEFINITION

C<static method SQL_QU_TABLE_DEFINITION : int ();>

Returns 4.

=head2 SQL_ROW_UPDATES

C<static method SQL_ROW_UPDATES : int ();>

Returns 11.

=head2 SQL_SCC_ISO92_CLI

C<static method SQL_SCC_ISO92_CLI : int ();>

Returns 2.

=head2 SQL_SCCO_LOCK

C<static method SQL_SCCO_LOCK : int ();>

Returns 2.

=head2 SQL_SCCO_OPT_ROWVER

C<static method SQL_SCCO_OPT_ROWVER : int ();>

Returns 4.

=head2 SQL_SCCO_OPT_VALUES

C<static method SQL_SCCO_OPT_VALUES : int ();>

Returns 8.

=head2 SQL_SCCO_READ_ONLY

C<static method SQL_SCCO_READ_ONLY : int ();>

Returns 1.

=head2 SQL_SCC_XOPEN_CLI_VERSION1

C<static method SQL_SCC_XOPEN_CLI_VERSION1 : int ();>

Returns 1.

=head2 SQL_SC_FIPS127_2_TRANSITIONAL

C<static method SQL_SC_FIPS127_2_TRANSITIONAL : int ();>

Returns 2.

=head2 SQL_SCHEMA_TERM

C<static method SQL_SCHEMA_TERM : int ();>

Returns 39.

=head2 SQL_SCHEMA_USAGE

C<static method SQL_SCHEMA_USAGE : int ();>

Returns 91.

=head2 SQL_SCROLL_CONCURRENCY

C<static method SQL_SCROLL_CONCURRENCY : int ();>

Returns 43.

=head2 SQL_SCROLL_OPTIONS

C<static method SQL_SCROLL_OPTIONS : int ();>

Returns 44.

=head2 SQL_SC_SQL92_ENTRY

C<static method SQL_SC_SQL92_ENTRY : int ();>

Returns 1.

=head2 SQL_SC_SQL92_FULL

C<static method SQL_SC_SQL92_FULL : int ();>

Returns 8.

=head2 SQL_SC_SQL92_INTERMEDIATE

C<static method SQL_SC_SQL92_INTERMEDIATE : int ();>

Returns 4.

=head2 SQL_SDF_CURRENT_DATE

C<static method SQL_SDF_CURRENT_DATE : int ();>

Returns 1.

=head2 SQL_SDF_CURRENT_TIME

C<static method SQL_SDF_CURRENT_TIME : int ();>

Returns 2.

=head2 SQL_SDF_CURRENT_TIMESTAMP

C<static method SQL_SDF_CURRENT_TIMESTAMP : int ();>

Returns 4.

=head2 SQL_SEARCH_PATTERN_ESCAPE

C<static method SQL_SEARCH_PATTERN_ESCAPE : int ();>

Returns 14.

=head2 SQL_SENSITIVE

C<static method SQL_SENSITIVE : int ();>

Returns 2.

=head2 SQL_SERVER_NAME

C<static method SQL_SERVER_NAME : int ();>

Returns 13.

=head2 SQL_SFKD_CASCADE

C<static method SQL_SFKD_CASCADE : int ();>

Returns 1.

=head2 SQL_SFKD_NO_ACTION

C<static method SQL_SFKD_NO_ACTION : int ();>

Returns 2.

=head2 SQL_SFKD_SET_DEFAULT

C<static method SQL_SFKD_SET_DEFAULT : int ();>

Returns 4.

=head2 SQL_SFKD_SET_NULL

C<static method SQL_SFKD_SET_NULL : int ();>

Returns 8.

=head2 SQL_SFKU_CASCADE

C<static method SQL_SFKU_CASCADE : int ();>

Returns 1.

=head2 SQL_SFKU_NO_ACTION

C<static method SQL_SFKU_NO_ACTION : int ();>

Returns 2.

=head2 SQL_SFKU_SET_DEFAULT

C<static method SQL_SFKU_SET_DEFAULT : int ();>

Returns 4.

=head2 SQL_SFKU_SET_NULL

C<static method SQL_SFKU_SET_NULL : int ();>

Returns 8.

=head2 SQL_SG_DELETE_TABLE

C<static method SQL_SG_DELETE_TABLE : int ();>

Returns 32.

=head2 SQL_SG_INSERT_COLUMN

C<static method SQL_SG_INSERT_COLUMN : int ();>

Returns 128.

=head2 SQL_SG_INSERT_TABLE

C<static method SQL_SG_INSERT_TABLE : int ();>

Returns 64.

=head2 SQL_SG_REFERENCES_COLUMN

C<static method SQL_SG_REFERENCES_COLUMN : int ();>

Returns 512.

=head2 SQL_SG_REFERENCES_TABLE

C<static method SQL_SG_REFERENCES_TABLE : int ();>

Returns 256.

=head2 SQL_SG_SELECT_TABLE

C<static method SQL_SG_SELECT_TABLE : int ();>

Returns 1024.

=head2 SQL_SG_UPDATE_COLUMN

C<static method SQL_SG_UPDATE_COLUMN : int ();>

Returns 4096.

=head2 SQL_SG_UPDATE_TABLE

C<static method SQL_SG_UPDATE_TABLE : int ();>

Returns 2048.

=head2 SQL_SG_USAGE_ON_CHARACTER_SET

C<static method SQL_SG_USAGE_ON_CHARACTER_SET : int ();>

Returns 2.

=head2 SQL_SG_USAGE_ON_COLLATION

C<static method SQL_SG_USAGE_ON_COLLATION : int ();>

Returns 4.

=head2 SQL_SG_USAGE_ON_DOMAIN

C<static method SQL_SG_USAGE_ON_DOMAIN : int ();>

Returns 1.

=head2 SQL_SG_USAGE_ON_TRANSLATION

C<static method SQL_SG_USAGE_ON_TRANSLATION : int ();>

Returns 8.

=head2 SQL_SG_WITH_GRANT_OPTION

C<static method SQL_SG_WITH_GRANT_OPTION : int ();>

Returns 16.

=head2 SQL_SNVF_BIT_LENGTH

C<static method SQL_SNVF_BIT_LENGTH : int ();>

Returns 1.

=head2 SQL_SNVF_CHARACTER_LENGTH

C<static method SQL_SNVF_CHARACTER_LENGTH : int ();>

Returns 4.

=head2 SQL_SNVF_CHAR_LENGTH

C<static method SQL_SNVF_CHAR_LENGTH : int ();>

Returns 2.

=head2 SQL_SNVF_EXTRACT

C<static method SQL_SNVF_EXTRACT : int ();>

Returns 8.

=head2 SQL_SNVF_OCTET_LENGTH

C<static method SQL_SNVF_OCTET_LENGTH : int ();>

Returns 16.

=head2 SQL_SNVF_POSITION

C<static method SQL_SNVF_POSITION : int ();>

Returns 32.

=head2 SQL_SO_DYNAMIC

C<static method SQL_SO_DYNAMIC : int ();>

Returns 4.

=head2 SQL_SO_FORWARD_ONLY

C<static method SQL_SO_FORWARD_ONLY : int ();>

Returns 1.

=head2 SQL_SO_KEYSET_DRIVEN

C<static method SQL_SO_KEYSET_DRIVEN : int ();>

Returns 2.

=head2 SQL_SO_MIXED

C<static method SQL_SO_MIXED : int ();>

Returns 8.

=head2 SQL_SO_STATIC

C<static method SQL_SO_STATIC : int ();>

Returns 16.

=head2 SQL_SP_BETWEEN

C<static method SQL_SP_BETWEEN : int ();>

Returns 2048.

=head2 SQL_SP_COMPARISON

C<static method SQL_SP_COMPARISON : int ();>

Returns 4096.

=head2 SQL_SPECIAL_CHARACTERS

C<static method SQL_SPECIAL_CHARACTERS : int ();>

Returns 94.

=head2 SQL_SP_EXISTS

C<static method SQL_SP_EXISTS : int ();>

Returns 1.

=head2 SQL_SP_IN

C<static method SQL_SP_IN : int ();>

Returns 1024.

=head2 SQL_SP_ISNOTNULL

C<static method SQL_SP_ISNOTNULL : int ();>

Returns 2.

=head2 SQL_SP_ISNULL

C<static method SQL_SP_ISNULL : int ();>

Returns 4.

=head2 SQL_SP_LIKE

C<static method SQL_SP_LIKE : int ();>

Returns 512.

=head2 SQL_SP_MATCH_FULL

C<static method SQL_SP_MATCH_FULL : int ();>

Returns 8.

=head2 SQL_SP_MATCH_PARTIAL

C<static method SQL_SP_MATCH_PARTIAL : int ();>

Returns 16.

=head2 SQL_SP_MATCH_UNIQUE_FULL

C<static method SQL_SP_MATCH_UNIQUE_FULL : int ();>

Returns 32.

=head2 SQL_SP_MATCH_UNIQUE_PARTIAL

C<static method SQL_SP_MATCH_UNIQUE_PARTIAL : int ();>

Returns 64.

=head2 SQL_SP_OVERLAPS

C<static method SQL_SP_OVERLAPS : int ();>

Returns 128.

=head2 SQL_SP_QUANTIFIED_COMPARISON

C<static method SQL_SP_QUANTIFIED_COMPARISON : int ();>

Returns 8192.

=head2 SQL_SP_UNIQUE

C<static method SQL_SP_UNIQUE : int ();>

Returns 256.

=head2 SQL_SQ_COMPARISON

C<static method SQL_SQ_COMPARISON : int ();>

Returns 1.

=head2 SQL_SQ_CORRELATED_SUBQUERIES

C<static method SQL_SQ_CORRELATED_SUBQUERIES : int ();>

Returns 16.

=head2 SQL_SQ_EXISTS

C<static method SQL_SQ_EXISTS : int ();>

Returns 2.

=head2 SQL_SQ_IN

C<static method SQL_SQ_IN : int ();>

Returns 4.

=head2 SQL_SQL92_DATETIME_FUNCTIONS

C<static method SQL_SQL92_DATETIME_FUNCTIONS : int ();>

Returns 155.

=head2 SQL_SQL92_FOREIGN_KEY_DELETE_RULE

C<static method SQL_SQL92_FOREIGN_KEY_DELETE_RULE : int ();>

Returns 156.

=head2 SQL_SQL92_FOREIGN_KEY_UPDATE_RULE

C<static method SQL_SQL92_FOREIGN_KEY_UPDATE_RULE : int ();>

Returns 157.

=head2 SQL_SQL92_GRANT

C<static method SQL_SQL92_GRANT : int ();>

Returns 158.

=head2 SQL_SQL92_NUMERIC_VALUE_FUNCTIONS

C<static method SQL_SQL92_NUMERIC_VALUE_FUNCTIONS : int ();>

Returns 159.

=head2 SQL_SQL92_PREDICATES

C<static method SQL_SQL92_PREDICATES : int ();>

Returns 160.

=head2 SQL_SQL92_RELATIONAL_JOIN_OPERATORS

C<static method SQL_SQL92_RELATIONAL_JOIN_OPERATORS : int ();>

Returns 161.

=head2 SQL_SQL92_REVOKE

C<static method SQL_SQL92_REVOKE : int ();>

Returns 162.

=head2 SQL_SQL92_ROW_VALUE_CONSTRUCTOR

C<static method SQL_SQL92_ROW_VALUE_CONSTRUCTOR : int ();>

Returns 163.

=head2 SQL_SQL92_STRING_FUNCTIONS

C<static method SQL_SQL92_STRING_FUNCTIONS : int ();>

Returns 164.

=head2 SQL_SQL92_VALUE_EXPRESSIONS

C<static method SQL_SQL92_VALUE_EXPRESSIONS : int ();>

Returns 165.

=head2 SQL_SQL_CONFORMANCE

C<static method SQL_SQL_CONFORMANCE : int ();>

Returns 118.

=head2 SQL_SQ_QUANTIFIED

C<static method SQL_SQ_QUANTIFIED : int ();>

Returns 8.

=head2 SQL_SR_CASCADE

C<static method SQL_SR_CASCADE : int ();>

Returns 32.

=head2 SQL_SR_DELETE_TABLE

C<static method SQL_SR_DELETE_TABLE : int ();>

Returns 128.

=head2 SQL_SR_GRANT_OPTION_FOR

C<static method SQL_SR_GRANT_OPTION_FOR : int ();>

Returns 16.

=head2 SQL_SR_INSERT_COLUMN

C<static method SQL_SR_INSERT_COLUMN : int ();>

Returns 512.

=head2 SQL_SR_INSERT_TABLE

C<static method SQL_SR_INSERT_TABLE : int ();>

Returns 256.

=head2 SQL_SRJO_CORRESPONDING_CLAUSE

C<static method SQL_SRJO_CORRESPONDING_CLAUSE : int ();>

Returns 1.

=head2 SQL_SRJO_CROSS_JOIN

C<static method SQL_SRJO_CROSS_JOIN : int ();>

Returns 2.

=head2 SQL_SRJO_EXCEPT_JOIN

C<static method SQL_SRJO_EXCEPT_JOIN : int ();>

Returns 4.

=head2 SQL_SRJO_FULL_OUTER_JOIN

C<static method SQL_SRJO_FULL_OUTER_JOIN : int ();>

Returns 8.

=head2 SQL_SRJO_INNER_JOIN

C<static method SQL_SRJO_INNER_JOIN : int ();>

Returns 16.

=head2 SQL_SRJO_INTERSECT_JOIN

C<static method SQL_SRJO_INTERSECT_JOIN : int ();>

Returns 32.

=head2 SQL_SRJO_LEFT_OUTER_JOIN

C<static method SQL_SRJO_LEFT_OUTER_JOIN : int ();>

Returns 64.

=head2 SQL_SRJO_NATURAL_JOIN

C<static method SQL_SRJO_NATURAL_JOIN : int ();>

Returns 128.

=head2 SQL_SRJO_RIGHT_OUTER_JOIN

C<static method SQL_SRJO_RIGHT_OUTER_JOIN : int ();>

Returns 256.

=head2 SQL_SRJO_UNION_JOIN

C<static method SQL_SRJO_UNION_JOIN : int ();>

Returns 512.

=head2 SQL_SR_REFERENCES_COLUMN

C<static method SQL_SR_REFERENCES_COLUMN : int ();>

Returns 2048.

=head2 SQL_SR_REFERENCES_TABLE

C<static method SQL_SR_REFERENCES_TABLE : int ();>

Returns 1024.

=head2 SQL_SR_RESTRICT

C<static method SQL_SR_RESTRICT : int ();>

Returns 64.

=head2 SQL_SR_SELECT_TABLE

C<static method SQL_SR_SELECT_TABLE : int ();>

Returns 4096.

=head2 SQL_SR_UPDATE_COLUMN

C<static method SQL_SR_UPDATE_COLUMN : int ();>

Returns 16384.

=head2 SQL_SR_UPDATE_TABLE

C<static method SQL_SR_UPDATE_TABLE : int ();>

Returns 8192.

=head2 SQL_SR_USAGE_ON_CHARACTER_SET

C<static method SQL_SR_USAGE_ON_CHARACTER_SET : int ();>

Returns 2.

=head2 SQL_SR_USAGE_ON_COLLATION

C<static method SQL_SR_USAGE_ON_COLLATION : int ();>

Returns 4.

=head2 SQL_SR_USAGE_ON_DOMAIN

C<static method SQL_SR_USAGE_ON_DOMAIN : int ();>

Returns 1.

=head2 SQL_SR_USAGE_ON_TRANSLATION

C<static method SQL_SR_USAGE_ON_TRANSLATION : int ();>

Returns 8.

=head2 SQL_SRVC_DEFAULT

C<static method SQL_SRVC_DEFAULT : int ();>

Returns 4.

=head2 SQL_SRVC_NULL

C<static method SQL_SRVC_NULL : int ();>

Returns 2.

=head2 SQL_SRVC_ROW_SUBQUERY

C<static method SQL_SRVC_ROW_SUBQUERY : int ();>

Returns 8.

=head2 SQL_SRVC_VALUE_EXPRESSION

C<static method SQL_SRVC_VALUE_EXPRESSION : int ();>

Returns 1.

=head2 SQL_SS_ADDITIONS

C<static method SQL_SS_ADDITIONS : int ();>

Returns 1.

=head2 SQL_SS_DELETIONS

C<static method SQL_SS_DELETIONS : int ();>

Returns 2.

=head2 SQL_SSF_CONVERT

C<static method SQL_SSF_CONVERT : int ();>

Returns 1.

=head2 SQL_SSF_LOWER

C<static method SQL_SSF_LOWER : int ();>

Returns 2.

=head2 SQL_SSF_SUBSTRING

C<static method SQL_SSF_SUBSTRING : int ();>

Returns 8.

=head2 SQL_SSF_TRANSLATE

C<static method SQL_SSF_TRANSLATE : int ();>

Returns 16.

=head2 SQL_SSF_TRIM_BOTH

C<static method SQL_SSF_TRIM_BOTH : int ();>

Returns 32.

=head2 SQL_SSF_TRIM_LEADING

C<static method SQL_SSF_TRIM_LEADING : int ();>

Returns 64.

=head2 SQL_SSF_TRIM_TRAILING

C<static method SQL_SSF_TRIM_TRAILING : int ();>

Returns 128.

=head2 SQL_SSF_UPPER

C<static method SQL_SSF_UPPER : int ();>

Returns 4.

=head2 SQL_SS_UPDATES

C<static method SQL_SS_UPDATES : int ();>

Returns 4.

=head2 SQL_STANDARD_CLI_CONFORMANCE

C<static method SQL_STANDARD_CLI_CONFORMANCE : int ();>

Returns 166.

=head2 SQL_STATIC_CURSOR_ATTRIBUTES1

C<static method SQL_STATIC_CURSOR_ATTRIBUTES1 : int ();>

Returns 167.

=head2 SQL_STATIC_CURSOR_ATTRIBUTES2

C<static method SQL_STATIC_CURSOR_ATTRIBUTES2 : int ();>

Returns 168.

=head2 SQL_STATIC_SENSITIVITY

C<static method SQL_STATIC_SENSITIVITY : int ();>

Returns 83.

=head2 SQL_STRING_FUNCTIONS

C<static method SQL_STRING_FUNCTIONS : int ();>

Returns 50.

=head2 SQL_SUBQUERIES

C<static method SQL_SUBQUERIES : int ();>

Returns 95.

=head2 SQL_SU_DML_STATEMENTS

C<static method SQL_SU_DML_STATEMENTS : int ();>

Returns 1.

=head2 SQL_SU_INDEX_DEFINITION

C<static method SQL_SU_INDEX_DEFINITION : int ();>

Returns 8.

=head2 SQL_SU_PRIVILEGE_DEFINITION

C<static method SQL_SU_PRIVILEGE_DEFINITION : int ();>

Returns 16.

=head2 SQL_SU_PROCEDURE_INVOCATION

C<static method SQL_SU_PROCEDURE_INVOCATION : int ();>

Returns 2.

=head2 SQL_SU_TABLE_DEFINITION

C<static method SQL_SU_TABLE_DEFINITION : int ();>

Returns 4.

=head2 SQL_SVE_CASE

C<static method SQL_SVE_CASE : int ();>

Returns 1.

=head2 SQL_SVE_CAST

C<static method SQL_SVE_CAST : int ();>

Returns 2.

=head2 SQL_SVE_COALESCE

C<static method SQL_SVE_COALESCE : int ();>

Returns 4.

=head2 SQL_SVE_NULLIF

C<static method SQL_SVE_NULLIF : int ();>

Returns 8.

=head2 SQL_SYSTEM_FUNCTIONS

C<static method SQL_SYSTEM_FUNCTIONS : int ();>

Returns 51.

=head2 SQL_TABLE_TERM

C<static method SQL_TABLE_TERM : int ();>

Returns 45.

=head2 SQL_TC_ALL

C<static method SQL_TC_ALL : int ();>

Returns 2.

=head2 SQL_TC_DDL_COMMIT

C<static method SQL_TC_DDL_COMMIT : int ();>

Returns 3.

=head2 SQL_TC_DDL_IGNORE

C<static method SQL_TC_DDL_IGNORE : int ();>

Returns 4.

=head2 SQL_TC_DML

C<static method SQL_TC_DML : int ();>

Returns 1.

=head2 SQL_TC_NONE

C<static method SQL_TC_NONE : int ();>

Returns 0.

=head2 SQL_TIMEDATE_ADD_INTERVALS

C<static method SQL_TIMEDATE_ADD_INTERVALS : int ();>

Returns 109.

=head2 SQL_TIMEDATE_DIFF_INTERVALS

C<static method SQL_TIMEDATE_DIFF_INTERVALS : int ();>

Returns 110.

=head2 SQL_TIMEDATE_FUNCTIONS

C<static method SQL_TIMEDATE_FUNCTIONS : int ();>

Returns 52.

=head2 SQL_TRANSACTION_CAPABLE

C<static method SQL_TRANSACTION_CAPABLE : int ();>

Returns 46.

=head2 SQL_TRANSACTION_ISOLATION_OPTION

C<static method SQL_TRANSACTION_ISOLATION_OPTION : int ();>

Returns 72.

=head2 SQL_TRANSACTION_READ_COMMITTED

C<static method SQL_TRANSACTION_READ_COMMITTED : int ();>

Returns 2.

=head2 SQL_TRANSACTION_READ_ONLY

C<static method SQL_TRANSACTION_READ_ONLY : int ();>

Returns 1.

=head2 SQL_TRANSACTION_READ_UNCOMMITTED

C<static method SQL_TRANSACTION_READ_UNCOMMITTED : int ();>

Returns 1.

=head2 SQL_TRANSACTION_READ_WRITE

C<static method SQL_TRANSACTION_READ_WRITE : int ();>

Returns 2.

=head2 SQL_TRANSACTION_REPEATABLE_READ

C<static method SQL_TRANSACTION_REPEATABLE_READ : int ();>

Returns 4.

=head2 SQL_TRANSACTION_SERIALIZABLE

C<static method SQL_TRANSACTION_SERIALIZABLE : int ();>

Returns 8.

=head2 SQL_TXN_CAPABLE

C<static method SQL_TXN_CAPABLE : int ();>

Returns 46.

=head2 SQL_TXN_ISOLATION_OPTION

C<static method SQL_TXN_ISOLATION_OPTION : int ();>

Returns 72.

=head2 SQL_TXN_READ_COMMITTED

C<static method SQL_TXN_READ_COMMITTED : int ();>

Returns 2.

=head2 SQL_TXN_READ_UNCOMMITTED

C<static method SQL_TXN_READ_UNCOMMITTED : int ();>

Returns 1.

=head2 SQL_TXN_REPEATABLE_READ

C<static method SQL_TXN_REPEATABLE_READ : int ();>

Returns 4.

=head2 SQL_TXN_SERIALIZABLE

C<static method SQL_TXN_SERIALIZABLE : int ();>

Returns 8.

=head2 SQL_TXN_VERSIONING

C<static method SQL_TXN_VERSIONING : int ();>

Returns 16.

=head2 SQL_UNION

C<static method SQL_UNION : int ();>

Returns 96.

=head2 SQL_UNION_STATEMENT

C<static method SQL_UNION_STATEMENT : int ();>

Returns 96.

=head2 SQL_UNSPECIFIED

C<static method SQL_UNSPECIFIED : int ();>

Returns 0.

=head2 SQL_USER_NAME

C<static method SQL_USER_NAME : int ();>

Returns 47.

=head2 SQL_US_UNION_ALL

C<static method SQL_US_UNION_ALL : int ();>

Returns 2.

=head2 SQL_US_UNION

C<static method SQL_US_UNION : int ();>

Returns 1.

=head2 SQL_U_UNION_ALL

C<static method SQL_U_UNION_ALL : int ();>

Returns 2.

=head2 SQL_U_UNION

C<static method SQL_U_UNION : int ();>

Returns 1.

=head2 SQL_XOPEN_CLI_YEAR

C<static method SQL_XOPEN_CLI_YEAR : int ();>

Returns 10000.

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License

