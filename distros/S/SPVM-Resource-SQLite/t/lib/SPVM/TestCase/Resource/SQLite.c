#include "spvm_native.h"
#include "sqlite3.h"

int32_t SPVM__TestCase__Resource__SQLite__test(SPVM_ENV* env, SPVM_VALUE* stack) {

  int32_t is_ok = 0;
  sqlite3* db = NULL;
  sqlite3_stmt* stmt = NULL;

  // 1. Basic Version Check
  if (sqlite3_libversion_number() <= 0) goto END_OF_FUNC;

  // 2. Compile-time Option Checks
  // These verify if the flags in your POD are actually compiled into the binary.
  if (!sqlite3_compileoption_used("ENABLE_FTS5")) goto END_OF_FUNC;
  if (!sqlite3_compileoption_used("ENABLE_RTREE")) goto END_OF_FUNC;
  if (!sqlite3_compileoption_used("ENABLE_COLUMN_METADATA")) goto END_OF_FUNC;
  if (!sqlite3_compileoption_used("ENABLE_MATH_FUNCTIONS")) goto END_OF_FUNC;
  if (!sqlite3_compileoption_used("ENABLE_DBSTAT_VTAB")) goto END_OF_FUNC;
  if (sqlite3_threadsafe() == 0) goto END_OF_FUNC;

  // 3. Runtime Behavior Check (Memory DB)
  if (sqlite3_open(":memory:", &db) != SQLITE_OK) goto END_OF_FUNC;

  // Verify MATH_FUNCTIONS via SQL
  const char* sql = "SELECT sqrt(16)";
  if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK) goto END_OF_FUNC;

  if (sqlite3_step(stmt) == SQLITE_ROW) {
    double result = sqlite3_column_double(stmt, 0);
    if (result != 4.0) goto END_OF_FUNC;
  } else {
    goto END_OF_FUNC;
  }

  // Everything passed!
  is_ok = 1;

END_OF_FUNC:
  // Clean up resources in reverse order
  if (stmt) sqlite3_finalize(stmt);
  if (db) sqlite3_close(db);

  stack[0].ival = is_ok;
  return 0;
}
