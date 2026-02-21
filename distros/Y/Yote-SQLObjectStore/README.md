# Yote-SQLObjectStore

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
    age      => 'INT',
    active   => 'BOOLEAN',
);

1;
```

## Column Types

### Scalar Types

Use standard SQL column definitions:

```perl
our %cols = (
    name    => 'VARCHAR(256)',
    count   => 'INT',
    amount  => 'DECIMAL(10,2)',
    notes   => 'TEXT',
);
```

### Reference Types

Reference types begin with `*`:

| Syntax | Meaning |
|--------|---------|
| `*PackageName` | Reference to object of that type |
| `*` | Reference to any object |
| `*ARRAY_TYPE` | Array of TYPE values |
| `*HASH<N>_TYPE` | Hash with max key size N, TYPE values |

TYPE can be:
- A SQL type (e.g., `VARCHAR(100)`, `INT`)
- A reference type (e.g., `*MyApp::User`, `*`)

### Examples

```perl
our %cols = (
    # Reference to specific object type
    manager => '*MyApp::User',

    # Reference to any object
    attachment => '*',

    # Array of integers
    scores => '*ARRAY_INT',

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
- **Arrays**: Stored in tables like `ARRAY_INT` or `ARRAY_REF` with (id, idx, val)
- **Hashes**: Stored in tables like `HASH_256_VARCHAR_100` with (id, hashkey, val)

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
