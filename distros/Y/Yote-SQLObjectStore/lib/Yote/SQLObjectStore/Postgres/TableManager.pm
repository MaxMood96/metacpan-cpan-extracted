package Yote::SQLObjectStore::Postgres::TableManager;

use 5.16.0;
use warnings;

use File::Grep qw(fgrep fmap fdo);
use Module::Load::Conditional qw(requires can_load);
use base 'Yote::SQLObjectStore::TableManager';

sub bigint_type    { 'BIGINT' }
sub int_type       { 'INTEGER' }
sub bigint_pk_type { 'BIGINT PRIMARY KEY' }

sub new_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    $table_name = lc $table_name;
    "ALTER TABLE $table_name ADD COLUMN $column_name $column_def";
}

sub change_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    $table_name = lc $table_name;
    my $bare_type = $column_def;
    $bare_type =~ s/ DEFAULT.*//i;
    $bare_type =~ s/ NOT NULL//i;
    return
        "ALTER TABLE $table_name ALTER COLUMN $column_name TYPE $bare_type USING ${column_name}::${bare_type}";
}

sub archive_column {
    my ($self, $table_name, $column_name) = @_;
    $table_name = lc $table_name;
    "ALTER TABLE $table_name RENAME COLUMN $column_name TO ${column_name}_DELETED",
}

sub undecorate_column {
    my ($self, $coldef) = @_;
    $coldef =~ s/ DEFAULT.*//i;
    $coldef =~ s/ NOT NULL//i;
    $coldef =~ s/character varying/varchar/i;
    $coldef =~ s/integer/integer/i;
    return $coldef;
}

sub abridged_columns_for_table {
    my ($self, $table_name) = @_;
    my $sth = $self->store->query_do(
        "SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name=? AND table_schema='public' ORDER BY ordinal_position",
        lc $table_name
    );

    my @col_pairs;
    while (my $row = $sth->fetchrow_arrayref) {
        my ($name, $type, $max_len) = @$row;
        $name = lc $name;
        $type = lc $type;
        next if $name eq 'id';

        # Map Postgres types to canonical form
        if ($type eq 'character varying') {
            $type = "varchar($max_len)";
        } elsif ($type eq 'integer') {
            $type = 'integer';
        } elsif ($type eq 'bigint') {
            $type = 'bigint';
        } elsif ($type eq 'smallint') {
            $type = 'smallint';
        } elsif ($type eq 'real') {
            $type = 'real';
        } elsif ($type eq 'text') {
            $type = 'text';
        }

        push @col_pairs, [$name, $type];
    }
    return @col_pairs;
}

sub abridged_columns_from_create_string {
    my ($self, $create) = @_;
    my ($new_columns_defs) = ($create =~ /^[^(]*\((.*?)(,\s*unique\s+\([^\)]+\))?\)$/i);
    my @col_pairs;

    for my $col (split ',', lc($new_columns_defs)) {
        $col =~ s/^\s+//;
        $col =~ s/\s+$//;
        my ($name, $def) = split /\s+/, $col, 2;
        next if $name eq 'id';
        $def = $self->undecorate_column( $def );
        push @col_pairs, [$name, $def];
    }

    return @col_pairs;
}

sub create_object_index_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS ObjectIndex (
    id          BIGSERIAL PRIMARY KEY,
    tablehandle VARCHAR(256),
    objectclass VARCHAR(256),
    live        SMALLINT
);
END
}

sub create_table_defs_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS TableDefs (
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(256),
    version REAL,
    UNIQUE (name)
);
END
}

sub create_table_versions_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS TableVersions (
    name         VARCHAR(256),
    version      INT,
    create_table TEXT,
    UNIQUE (name, version)
);
END
}

1;
