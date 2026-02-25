# Alien::sqlite\_vec

Provides the [sqlite-vec](https://github.com/asg017/sqlite-vec) extension for SQLite as an Alien distribution. sqlite-vec enables fast vector search (KNN) directly inside SQLite.

Downloads and compiles sqlite-vec v0.1.6 from the amalgamation source.

## Synopsis

```perl
use Alien::sqlite_vec;
use DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:");
$dbh->sqlite_enable_load_extension(1);

my ($vec_path) = Alien::sqlite_vec->dynamic_libs;
$dbh->do("SELECT load_extension(?)", {}, $vec_path);

# Now you can use vec0 virtual tables
$dbh->do("CREATE VIRTUAL TABLE my_vectors USING vec0(embedding float[384])");
```

## Installation

```
cpanm Alien::sqlite_vec
```

Requires a C compiler and SQLite development headers (provided by `DBD::SQLite`).
