package Yote::SQLObjectStore::SQLite::TableManager;

use 5.16.0;
use warnings;

use File::Grep qw(fgrep fmap fdo);
use Module::Load::Conditional qw(requires can_load);
use base 'Yote::SQLObjectStore::TableManager';

sub map_type {
    my ($self, $type) = @_;
    return 'INTEGER' if $type =~ /^(INTEGER|BIGINT|SMALLINT)$/i;
    return 'REAL'    if $type =~ /^(FLOAT|DOUBLE|REAL)$/i;
    return 'NUMERIC' if $type =~ /^(DECIMAL|NUMERIC)\(\d+[,\s]*\d*\)$/i;
    return 'INTEGER' if $type =~ /^BOOLEAN$/i;
    return 'TEXT'    if $type =~ /^(TIMESTAMP|DATE)$/i;
    return $type;
}

sub new_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    "ALTER TABLE $table_name ADD COLUMN $column_name $column_def";
}

sub change_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    # not really needed in sqlite, since there is only one data
    # type, but here we go
    return 
        "ALTER TABLE $table_name RENAME COLUMN $column_name TO ${column_name}_mv",
        "ALTER TABLE $table_name ADD COLUMN $column_name $column_def",
        "UPDATE $table_name SET $column_name = ${column_name}_mv",
        "ALTER TABLE $table_name DROP COLUMN ${column_name}_mv";
}

sub archive_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    "ALTER TABLE $table_name RENAME COLUMN $column_name TO ${column_name}_DELETED",
}

sub undecorate_column {
    my ($self, $coldef) = @_;
    return $coldef;
}

sub abridged_columns_for_table {
    my ($self, $table_name) = @_;
    my $sth = $self->store->query_do( "PRAGMA table_info($table_name)" );

    my @col_pairs;
    while (my $row = $sth->fetchrow_arrayref) {
        my (undef, $name, $def) = map { lc } grep { defined } @$row;
        next if $name eq 'id';
        $def = $self->undecorate_column( $def );
        push @col_pairs, [$name, $def];
    }
    return @col_pairs;
}

sub abridged_columns_from_create_string {
    my ($self, $create) = @_;
    my ($new_columns_defs) = ($create =~ /^[^(]*\((.*?)(,unique +\([^\)]+\))?\)$/i);
    my @col_pairs;

    for my $col (split ',', lc($new_columns_defs)) {
        my ($name, $def) = split /\s+/, $col, 2;
        next if $name eq 'id';
        # Strip DEFAULT clause to match PRAGMA table_info output
        # (PRAGMA returns the default value separately, not in the type)
        $def =~ s/\s+default\s+.*//i if $def;
        $def = $self->undecorate_column( $def );
        push @col_pairs, [$name, $def];
    }
    
    return @col_pairs;
}



sub create_object_index_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS ObjectIndex ( 
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    tablehandle TEXT,
    objectclass TEXT,
    live        BOOLEAN
);
END
}

sub create_table_defs_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS TableDefs ( 
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT,
    version FLOAT,
    UNIQUE (name)
);
END
}

sub create_table_versions_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS TableVersions (
    name         TEXT,
    version      INT,
    create_table TEXT,
    UNIQUE (name, version)
);
END
}

1;
