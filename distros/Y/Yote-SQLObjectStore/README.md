# Yote-SQLObjectStore v0.03

A schema-enforced object persistence layer backed by SQL databases (SQLite, MariaDB, or Postgres).

## Overview

Yote-SQLObjectStore provides typed object persistence with SQL storage. Unlike the schema-less Yote-ObjectStore, SQLObjectStore enforces column types defined in Perl packages and automatically generates appropriate SQL tables.

Key features:

- **Typed schemas** - Object fields are defined with SQL types or reference types
- **Automatic table generation** - Scans packages and creates/updates SQL tables
- **Runtime type checking** - Validates values match declared types
- **Dirty tracking** - Only saves modified objects
- **Multiple backends** - SQLite, MariaDB, and Postgres support
- **Tied collections** - Transparent persistence for arrays and hashes

## Installation

```bash
perl Build.PL
./Build
./Build test
./Build install
```

## Quick Start

```perl
use Yote::SQLObjectStore;

# Connect to database
my $store = Yote::SQLObjectStore->new(
    'SQLite',  # or 'MariaDB' or 'Postgres'
    dbname   => 'myapp.db',
    root     => 'MyApp::Root',
);

# Generate tables from package definitions
$store->make_all_tables(@INC) if $store->needs_table_updates(@INC);

$store->open;

my $root = $store->get_root;

# Create and store objects
my $user = $store->new_obj('MyApp::User',
    name  => 'alice',
    email => 'alice@example.com',
);
$root->get_users->{alice} = $user;

$store->save;
```

## Defining Object Classes

Object classes inherit from the database-specific Obj base class and declare their schema via `%cols`:

```perl
package MyApp::User;
use base 'Yote::SQLObjectStore::SQLite::Obj';
# or 'Yote::SQLObjectStore::MariaDB::Obj'
# or 'Yote::SQLObjectStore::Postgres::Obj'

our %cols = (
    name     => 'VARCHAR(128)',
    email    => 'VARCHAR(256)',
    age      => 'INTEGER',
    active   => 'BOOLEAN',
);

1;
```

## Column Types

### Scalar Types

Scalar types use ANSI SQL standard names. Each backend automatically
translates these to native database types, so the same `%cols`
definition works across SQLite, MariaDB, and PostgreSQL.

| Standard Type | Description |
|---------------|-------------|
| `TEXT` | Variable-length text, no length limit |
| `VARCHAR(N)` | Variable-length text, max N characters |
| `INTEGER` | Standard integer |
| `BIGINT` | Large integer |
| `SMALLINT` | Small integer |
| `FLOAT` | Single-precision floating point |
| `DOUBLE` | Double-precision floating point |
| `DECIMAL(M,D)` | Exact decimal, M total digits, D after decimal |
| `BOOLEAN` | True/false value |
| `BLOB` | Binary data |
| `TIMESTAMP` | Date and time |
| `DATE` | Date only |

```perl
our %cols = (
    name    => 'VARCHAR(256)',
    count   => 'INTEGER',
    amount  => 'DECIMAL(10,2)',
    notes   => 'TEXT',
    active  => 'BOOLEAN',
);
```

#### Backend Type Mapping

Each backend maps these standard types to native equivalents:

| Standard | SQLite | MariaDB | PostgreSQL |
|----------|--------|---------|------------|
| `TEXT` | TEXT | TEXT | TEXT |
| `VARCHAR(N)` | VARCHAR(N) | VARCHAR(N) | VARCHAR(N) |
| `INTEGER` | INTEGER | INT | INTEGER |
| `BIGINT` | INTEGER | BIGINT | BIGINT |
| `SMALLINT` | INTEGER | SMALLINT | SMALLINT |
| `FLOAT` | REAL | FLOAT | REAL |
| `DOUBLE` | REAL | DOUBLE | DOUBLE PRECISION |
| `DECIMAL(M,D)` | NUMERIC | DECIMAL(M,D) | DECIMAL(M,D) |
| `BOOLEAN` | INTEGER | TINYINT(1) | BOOLEAN |
| `BLOB` | BLOB | BLOB | BYTEA |
| `TIMESTAMP` | TEXT | TIMESTAMP | TIMESTAMP |
| `DATE` | TEXT | DATE | DATE |

### Reference Types

Reference types begin with `*` and store object IDs internally:

| Syntax | Meaning |
|--------|---------|
| `*PackageName` | Reference to object of that type |
| `*` | Reference to any object |
| `*ARRAY_<type>` | Array of values or references |
| `*HASH<N>_<type>` | Hash with max key size N |

`<type>` can be:
- A scalar type (e.g., `VARCHAR(100)`, `INTEGER`)
- `*` (any object reference)
- `*Package::Name` (typed object reference)

### Examples

```perl
our %cols = (
    # Reference to specific object type
    manager => '*MyApp::User',

    # Reference to any object
    attachment => '*',

    # Array of integers
    scores => '*ARRAY_INTEGER',

    # Array of User objects
    friends => '*ARRAY_*MyApp::User',

    # Hash (256-char keys) of strings
    attributes => '*HASH<256>_VARCHAR(1024)',

    # Hash of User objects
    users => '*HASH<128>_*MyApp::User',

    # Hash of arrays of any reference
    groups => '*HASH<256>_*ARRAY_*',
);
```

## Table Generation

SQLObjectStore scans `@INC` for packages inheriting from the Obj base class and generates appropriate SQL tables:

```perl
# Check if tables need updating
if ($store->needs_table_updates(@INC)) {
    # Preview the SQL
    my @sql = $store->make_all_tables_sql(@INC);
    print join("\n", @sql);

    # Or execute directly
    $store->make_all_tables(@INC);
}
```

Tables are created for:
- Each object class (one row per object instance)
- Each array type (id, idx, val columns)
- Each hash type by key size and value type (id, hashkey, val columns)

## Architecture

```
+------------------+     +------------------------------+
| Yote::SQLObject  |---->| SQLite, MariaDB, or Postgres |
| Store            |     | Backend                      |
+------------------+     +------------------------------+
        |
        v
+------------------+
| TableManager     |  Generates/updates SQL tables
+------------------+
        |
        v
+------------------+     +------------------+
| BaseObj          |<--->| TiedHash         |
| (object fields)  |     | TiedArray        |
+------------------+     +------------------+
```

### Storage Model

- **Objects**: Stored in tables named after their package (e.g., `MyApp_User`)
- **Arrays**: Stored in tables like `ARRAY_INTEGER` or `ARRAY_REF` with (id, idx, val)
- **Hashes**: Stored in tables like `HASH_256_VARCHAR_100_` with (id, hashkey, val)

## Backend Notes

### SQLite
- File-based, no server needed
- Uses `INSERT OR REPLACE` / `INSERT OR IGNORE`
- Uses file-based locking for multi-process safety
- Connect with `BASE_DIRECTORY`

### MariaDB
- Uses `REPLACE` / `INSERT IGNORE`
- Uses `BIGINT UNSIGNED` for reference columns
- Connect with `dbname`, `username`, `password`, `host`, `port`

### Postgres
- Uses `BIGSERIAL` / `SERIAL` for auto-increment primary keys
- Uses `BIGINT` (no `UNSIGNED`) for reference columns
- Postgres lowercases unquoted identifiers; the adapter handles this transparently
- Connect with `dbname`, `username`, `password`, `host`, `port`

## Transactions

```perl
$store->begin_transaction;

eval {
    # Make changes
    $user->set_name('bob');
    $store->save;
    $store->commit_transaction;
};
if ($@) {
    $store->rollback_transaction;
}
```

## Differences from Yote-ObjectStore

| Feature | ObjectStore | SQLObjectStore |
|---------|-------------|----------------|
| Storage | File-based (RecordStore) | SQL database |
| Schema | Schema-less | Typed via %cols |
| Queries | ID lookup only | ID lookup (SQL queries possible) |
| Types | Runtime flexible | Compile-time defined |
| Tables | Single data store | Table per type |

## Requirements

- Perl 5.16+
- DBI
- DBD::SQLite, DBD::MariaDB, and/or DBD::Pg (depending on backend)
- Set::Scalar
- File::Grep
- Module::Load::Conditional

## License

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

## Author

Eric Wolf
