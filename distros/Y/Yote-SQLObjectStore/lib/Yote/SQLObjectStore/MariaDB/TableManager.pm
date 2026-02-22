package Yote::SQLObjectStore::MariaDB::TableManager;

use 5.16.0;
use warnings;

use File::Grep qw(fgrep fmap fdo);
use Module::Load::Conditional qw(requires can_load);
use base 'Yote::SQLObjectStore::TableManager';

sub map_type {
    my ($self, $type) = @_;
    return 'INT'        if $type =~ /^INTEGER$/i;
    return 'TINYINT(1)' if $type =~ /^BOOLEAN$/i;
    return $type;
}

sub new_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    "ALTER TABLE $table_name ADD COLUMN $column_name $column_def";
}

sub change_column {
    my ($self, $table_name, $column_name, $column_def) = @_;
    return 
        "ALTER TABLE $table_name CHANGE COLUMN $column_name $column_name $column_def";
}

sub archive_column {
    my ($self, $table_name, $column_name) = @_;
    "ALTER TABLE $table_name RENAME COLUMN $column_name TO ${column_name}_DELETED",
}

sub undecorate_column {
    my ($self, $coldef) = @_;
    $coldef =~ s/int\(\d+\)/int/i;
    $coldef =~ s/ DEFAULT.*//i;
    $coldef =~ s/ on update.*//i;
    return $coldef;
}

sub abridged_columns_for_table {
    my ($self, $table_name) = @_;
    my $sth = $self->store->query_do( "DESC $table_name" );

    my @col_pairs;
    while (my $row = $sth->fetchrow_arrayref) {
        my ($name, $def) = map { lc } grep { defined } @$row;
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
        $def = $self->undecorate_column( $def );
        push @col_pairs, [$name, $def];
    }
    
    return @col_pairs;
}

sub create_object_index_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS ObjectIndex ( 
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tablehandle VARCHAR(256),
    objectclass VARCHAR(256),
    live        TINYINT
);
END
}

sub create_table_defs_sql {
    return <<"END";
CREATE TABLE IF NOT EXISTS TableDefs ( 
    id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name    VARCHAR(256),
    version FLOAT,
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
