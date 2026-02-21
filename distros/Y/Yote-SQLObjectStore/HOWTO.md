# Yote-SQLObjectStore HOWTO

A practical guide to getting started with Yote-SQLObjectStore.

## Setting Up a New Project

### 1. Choose Your Backend

Yote-SQLObjectStore supports three backends. Pick the one that fits your needs:

- **SQLite** - Zero setup, file-based, good for small apps and development
- **MariaDB** - Full-featured relational database, good for production
- **Postgres** - Full-featured relational database, good for production

### 2. Install Dependencies

```bash
# Core
cpanm DBI Set::Scalar File::Grep Module::Load::Conditional

# Pick your backend driver
cpanm DBD::SQLite    # for SQLite
cpanm DBD::MariaDB   # for MariaDB
cpanm DBD::Pg        # for Postgres
```

### 3. Define Your Object Classes

Every object class needs two things: a base class and a `%cols` hash defining its schema.

```perl
package MyApp::Root;
use base 'Yote::SQLObjectStore::Postgres::Obj';

our %cols = (
    users    => '*HASH<256>_*MyApp::User',
    settings => '*HASH<256>_VARCHAR(2000)',
);
1;


package MyApp::User;
use base 'Yote::SQLObjectStore::Postgres::Obj';

our %cols = (
    name     => 'VARCHAR(256)',
    email    => 'VARCHAR(256)',
    bio      => 'TEXT',
    posts    => '*ARRAY_*MyApp::Post',
    friends  => '*HASH<256>_*MyApp::User',
);
1;


package MyApp::Post;
use base 'Yote::SQLObjectStore::Postgres::Obj';

our %cols = (
    title   => 'VARCHAR(256)',
    body    => 'TEXT',
    author  => '*MyApp::User',
    tags    => '*ARRAY_VARCHAR(100)',
);
1;
```

Replace `Postgres` with `MariaDB` or `SQLite` depending on your backend. The `%cols` definitions stay the same.

### 4. Connect and Create Tables

#### SQLite

```perl
use Yote::SQLObjectStore;

my $store = Yote::SQLObjectStore->new( 'SQLite',
    BASE_DIRECTORY => '/path/to/data',
    root_package   => 'MyApp::Root',
);

$store->make_all_tables(@INC);
$store->open;
```

#### MariaDB

```perl
my $store = Yote::SQLObjectStore->new( 'MariaDB',
    dbname   => 'myapp',
    username => 'dbuser',
    password => 'dbpass',
    host     => 'localhost',
    port     => 3306,
);

$store->make_all_tables(@INC);
$store->open;
```

#### Postgres

```perl
my $store = Yote::SQLObjectStore->new( 'Postgres',
    dbname   => 'myapp',
    username => 'dbuser',
    password => 'dbpass',
    host     => 'localhost',
    port     => 5432,
);

$store->make_all_tables(@INC);
$store->open;
```

## Working with Objects

### Creating Objects

```perl
my $user = $store->new_obj( 'MyApp::User',
    name  => 'alice',
    email => 'alice@example.com',
);
```

Fields are validated against `%cols`. Passing a field that doesn't exist will die.

### Getters and Setters

Every field in `%cols` gets auto-generated `get_` and `set_` methods:

```perl
my $name = $user->get_name;       # 'alice'
$user->set_email('new@email.com');

# get_ with a default: sets and returns the value if the field is currently undef
my $bio = $user->get_bio( "No bio yet" );
```

### Saving

Objects are tracked as dirty when modified. Save writes all dirty objects in a transaction:

```perl
$store->save;          # saves all dirty objects
$store->save($user);   # saves just this one object
```

### The Root Object

The root is the entry point to your entire object tree. It's created automatically on first `open`:

```perl
my $root = $store->fetch_root;
my $users = $root->get_users;
$users->{alice} = $user;
$store->save;
```

## Working with Collections

### Hashes

Hashes are tied Perl hashes backed by the database. They work like regular hashes:

```perl
my $hash = $store->new_hash( '*HASH<256>_VARCHAR(100)', foo => 'bar' );

$hash->{key} = 'value';
my $val = $hash->{key};
delete $hash->{key};
my @keys = keys %$hash;
```

The `<256>` means keys can be at most 256 characters.

### Arrays

Arrays are tied Perl arrays backed by the database:

```perl
my $arr = $store->new_array( '*ARRAY_VARCHAR(200)', 'first', 'second' );

push @$arr, 'third';
my $val = $arr->[0];
my $len = scalar @$arr;
my $popped = pop @$arr;
splice @$arr, 1, 1, 'replaced';
```

### Reference Collections

Collections can hold object references instead of scalar values:

```perl
my $ref_hash = $store->new_hash( '*HASH<256>_*MyApp::User' );
$ref_hash->{alice} = $user;

my $ref_arr = $store->new_array( '*ARRAY_*MyApp::Post' );
push @$ref_arr, $post;
```

Use `*` as the value type to allow any reference type:

```perl
my $anything = $store->new_hash( '*HASH<256>_*' );
$anything->{user}  = $user;
$anything->{posts} = $ref_arr;
```

## Path-Based Access

You can navigate the object tree using path strings, starting from the root:

```perl
# Fetch values by path
my $email = $store->fetch_string_path( '/users/alice/email' );
my $post  = $store->fetch_string_path( '/users/alice/posts/0' );

# Check if a path exists
if ($store->has_path( 'users', 'alice' )) { ... }

# Delete a value at a path
$store->del_string_path( '/users/alice/bio' );
```

### ensure_path

`ensure_path` navigates a path, creating objects along the way if they don't exist:

```perl
# Ensure a scalar value exists
$store->ensure_path( '/settings/site_name|My Site' );

# Ensure an object exists (creates it if missing)
my $bob = $store->ensure_path( '/users/bob|MyApp::User' );

# Ensure a hash exists
my $prefs = $store->ensure_path( '/users/alice/prefs|*HASH<256>_VARCHAR(256)' );

# String path format: /key|type_or_value/key|type_or_value
```

### ensure_paths

Ensure multiple paths atomically in a transaction. If any path fails, none are applied:

```perl
$store->ensure_paths(
    '/settings/version|1.0',
    '/settings/mode|production',
);
```

### set_path

Set a value at a path (path must already exist up to the parent):

```perl
$store->set_path( 'users', 'charlie',
    $store->new_obj('MyApp::User', name => 'charlie') );
```

## Finder Methods

Query objects by their scalar fields:

```perl
# Find one object by field value
my $user = $store->find_by( 'MyApp::User', 'email', 'alice@example.com' );

# Find all matching objects
my @active = $store->find_all_by( 'MyApp::User', 'status', 'active',
    order_by => 'name ASC',
    limit    => 10,
    offset   => 0,
);

# Find with multiple criteria (AND logic)
my @admins = $store->find_where( 'MyApp::User',
    role   => 'admin',
    active => 1,
    _order_by => 'name ASC',
    _limit    => 50,
);

# Find single match with _single
my $user = $store->find_where( 'MyApp::User',
    email => 'alice@example.com',
    _single => 1,
);
```

Only scalar fields (not reference fields) can be searched.

## Schema Evolution

When you change `%cols` in a package, run `make_all_tables` again. The table manager detects differences and generates ALTER TABLE statements:

- New columns are added
- Removed columns are renamed with a `_DELETED` suffix (archived, not dropped)
- Changed column types are altered in place

```perl
# Preview the SQL that would run
my @sql = $store->make_all_tables_sql(@INC);
for my $s (@sql) {
    my ($query, @params) = @$s;
    print "$query\n";
}

# Or just run it
$store->make_all_tables(@INC);
```

## Transactions

```perl
$store->start_transaction;

eval {
    $user->set_name('bob');
    $store->save;
    $store->commit_transaction;
};
if ($@) {
    $store->rollback_transaction;
}
```

`save` already wraps its work in a transaction. Use explicit transactions when you need multiple operations to be atomic.

## Column Type Reference

### Scalar Types

Any SQL column type works:

| Type | Example |
|------|---------|
| `VARCHAR(N)` | `'VARCHAR(256)'` |
| `TEXT` | `'TEXT'` |
| `INT` | `'INT'` |
| `BIGINT` | `'BIGINT'` |
| `FLOAT` | `'FLOAT'` |
| `BOOLEAN` | `'BOOLEAN'` |
| `DECIMAL(M,N)` | `'DECIMAL(10,2)'` |

### Reference Types

All reference types start with `*`:

| Syntax | Meaning | Example |
|--------|---------|---------|
| `*PkgName` | Typed object reference | `'*MyApp::User'` |
| `*` | Any object reference | `'*'` |
| `*ARRAY_TYPE` | Array of values or refs | `'*ARRAY_VARCHAR(100)'` |
| `*ARRAY_*PkgName` | Array of typed objects | `'*ARRAY_*MyApp::Post'` |
| `*ARRAY_*` | Array of any reference | `'*ARRAY_*'` |
| `*HASH<N>_TYPE` | Hash with max key size N | `'*HASH<256>_VARCHAR(100)'` |
| `*HASH<N>_*PkgName` | Hash of typed objects | `'*HASH<256>_*MyApp::User'` |
| `*HASH<N>_*` | Hash of any reference | `'*HASH<256>_*'` |

### Nesting

Reference types can be nested:

```perl
our %cols = (
    # Array of arrays of strings
    grid => '*ARRAY_*ARRAY_VARCHAR(200)',

    # Hash of arrays of any reference
    groups => '*HASH<256>_*ARRAY_*',
);
```

## Custom Table Names

By default, table names are derived from the package name. Override with `$table`:

```perl
package MyApp::Models::User;
use base 'Yote::SQLObjectStore::Postgres::Obj';

our $table = 'Users';
our %cols = ( ... );
1;
```

## Switching Backends

To switch backends, change two things:

1. The flavor string passed to `Yote::SQLObjectStore->new`
2. The base class in your object packages

The `%cols` definitions, path operations, and all store API calls remain identical across backends.
