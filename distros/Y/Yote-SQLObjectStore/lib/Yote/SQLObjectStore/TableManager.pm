package Yote::SQLObjectStore::TableManager;

use 5.16.0;
use warnings;

use mro;
use File::Grep qw(fgrep fmap fdo);
use Module::Load::Conditional qw(requires can_load);
use Set::Scalar;

sub new {
    my ($pkg, $store) = @_;
    return bless { store => $store }, $pkg;
}

sub store {
    return shift->{store};
}

sub walk_for_perl {
    my ($self, $base_obj_pkg, $seen_packages, $root, @path) = @_;

    my @mods;

    my $path = join( '/', $root, @path );

    my @perls = map { my $fn = $_->{filename}; $fn =~ s/(.*\/)([^\/]*).pm/$2/; join( "::", @path, $fn ) }
                grep { $_->{count} }
                fgrep { /Yote::.*::Obj/ }
                glob "$path/*pm";

    my %files = reverse %INC;

    for my $mod (@perls) {
        my $as_path = join( '/', split( /::/, $mod)) . '.pm';
        next if $files{$as_path};
        next if $seen_packages->{$mod}++;

        my @reqlist = grep { $_ && $_ !~ /^(base|strict|warnings)$/ } requires( $mod );
        if ( $mod->isa( $base_obj_pkg ) or 
             grep { $_ eq $base_obj_pkg } @reqlist) {
            push @mods, $mod;
        }
    }

    # check for subdirs
    opendir my $dh, $path or return;

    for my $file (grep { $_ !~ /^..?$/ } readdir($dh)) {
        if( -d "$path/$file" ) {
            push @mods, $self->walk_for_perl( $base_obj_pkg, $seen_packages, $root, @path, $file );
        }
    }
    return @mods;
}

sub find_obj_packages {
    my ($self,$base_obj_package, @INC_PATH) = @_;
    my @mods;
    my $seen_packages = {};
    for my $dir (@INC_PATH) {
        next if $dir eq '.';
        # find the perl files in this directory
        push @mods, $self->walk_for_perl( $base_obj_package, $seen_packages, $dir );
    }
    return @mods;
}

sub bigint_type    { 'BIGINT UNSIGNED' }
sub int_type       { 'INT UNSIGNED' }
sub bigint_pk_type { 'BIGINT UNSIGNED PRIMARY KEY' }

# Maps an ANSI SQL standard type to the native type for this backend.
# Subclasses override to provide backend-specific translations.
sub map_type {
    my ($self, $type) = @_;
    return $type;
}

sub label_to_table {
    my ($self, $label) = @_;

    if ($label =~ /^\*HASH<(\d+)>_\*/) {
        return "HASH_${1}_REF";
    }
    if ($label =~ /^\*HASH<(\d+)>_(.*)/) {
        my ($key_size, $val_type) = ($1, $2);
        $val_type =~ s/[()<>,]/_/g;
        return "HASH_${key_size}_$val_type";
    }
    elsif ($label =~ /^\*ARRAY_\*/) {
        return "ARRAY_REF";
    }
    elsif ($label =~ /^\*ARRAY_(.*)/) {
        my $array_type = $1;
        $array_type =~ s/[<>(),]/_/g;
        return "ARRAY_$array_type";
    }
    return $label;
}

sub generate_hash_table {
    my ($self, $name2table, $hash_key_size, $field_type) = @_;

    # generates table sql and sticks it in name2table hash.
    # there is a different hash table for every
    # key size / field type combination.
    #
    # all reference field types of the same key size share
    # the same table. yote still enforces the
    # type information for the field which area stored in the
    # object model packages. That means a hash of hash references
    # and a hash of array references (both with keysize 256) are
    # stored in the HASH_256_REF table. yote makes sure an array
    # ref may not be stored in the hash of hashes table and a hash
    # ref not stored in the hash of arrays table.
    #

    my ($is_ref, $field_value) = ( $field_type =~ /(\*)?(.*)/ );

    my $table_label = join '_', "*HASH<$hash_key_size>", $field_type;
    my $table_name = $self->label_to_table( $table_label );

    return if $name2table->{$table_name};

    my @column_sql = (
        "id ".$self->bigint_type,
        "hashkey VARCHAR($hash_key_size)",
        );

    if ($is_ref) {
        push @column_sql, "val ".$self->bigint_type;
    } else {
        # scalar field
        push @column_sql, "val ".$self->map_type($field_type);
    }

    push @column_sql, "UNIQUE (id,hashkey)";
    $name2table->{$table_name} = "CREATE TABLE IF NOT EXISTS $table_name (" .
        join( ',', @column_sql ) .')';

    $self->generate_reference_table($name2table,$field_value) if $is_ref;
}

sub generate_array_table {
    my ($self, $name2table, $field_type) = @_;

    # generating a virtual table data structure
    # representing an array that has column reference
    # constraints
    #
    # the array items may be references or values.
    #
    # if values, they are a sql type like varchar(123) or tinyint
    #
    # if references, they are an integer that points to the ARRAY_REF
    # table, but the particular perl array object does type checking
    # using this data structure
    #
    # the table has a label to identify it. if it is a typed reference
    # it has an alias_of field that points to the table label ARRAY_REF
    #

    my ($is_ref, $field_value) = ( $field_type =~ /(\*)?(.*)/ );

    my $table_label = join '_', "*ARRAY", $field_type;
    my $table_name = $self->label_to_table( $table_label );

    return if $name2table->{$table_name};

    my @column_sql = (
        "id ".$self->bigint_type,
        "idx ".$self->int_type,
        );

    if ($is_ref) {
        push @column_sql, "val ".$self->bigint_type;
    }
    else {
        push @column_sql, "val ".$self->map_type($field_value);
    }

    push @column_sql, "UNIQUE (id,idx)";

    $name2table->{$table_name} = "CREATE TABLE IF NOT EXISTS $table_name (" .
        join( ',', @column_sql ) .')';

    $self->generate_reference_table($name2table,$field_value) if $is_ref;
}

sub generate_reference_table {
    my ($self, $name2table, $col_type) = @_;
    if ($col_type =~ /^((\*(ARRAY|HASH(<(\d*)>)?))_)?(.*)/) {
        my ($is_container,
            $container_label,
            $hash_key_size,
            $value_type) = ( $1, $3, $5, $6 );
        if ($is_container && $container_label eq 'ARRAY') {
            $self->generate_array_table( $name2table, $value_type );
        } elsif( $is_container ) {
            $self->generate_hash_table( $name2table, $hash_key_size, $value_type );
        } elsif ($value_type =~ /^\*(.+)/) {
            $self->generate_table_from_module( $name2table, $1 );
        }
    }
}

sub generate_table_from_module {
    my ($self, $name2table, $mod) = @_;

    my $table_label = $mod;

    if (! can_load( modules => { $mod => 0 }, verbose => 1 )) {
        die "unable to load module '$mod'";
    }

    my $table_name = $mod->table_name; #join '_', reverse split /::/, $mod;

    return if $name2table->{$table_name};

    my @column_sql = ( "id ".$self->bigint_pk_type );
    my %column_defs;

    my $cols = $mod->cols;
    $name2table->{$table_name} = {
        module           => $mod,
        table_name       => $table_name,
        column_defs      => $cols,
    };

    my @ref_types;
    for my $col_name (sort keys %$cols) {
        die "Invalid Column Name for yote '$col_name'" if $col_name =~ /[^_a-zA-Z0-9]/;
        my $col_type = $cols->{$col_name};
        if ($col_type =~ /^\*/) {
            # a reference
            push @ref_types, $col_type;
            push @column_sql, "$col_name ".$self->bigint_type;
        } else {
            # a scalar - map abstract type to native SQL type
            push @column_sql, "$col_name ".$self->map_type($col_type);
        }
    }

    $name2table->{$table_name} = "CREATE TABLE IF NOT EXISTS $table_name (" .
        join( ',', @column_sql ) .')';

    for my $ref_type (@ref_types) {
        $self->generate_reference_table($name2table,$ref_type);
    }
}

sub generate_tables_sql {
    my ($self, $base_obj_package, @INC_PATH) = @_;

    my @mods = $self->find_obj_packages( $base_obj_package, @INC_PATH );

    my $name2table = {};

    for my $mod (@mods) {
        eval {
            my $package_file = $mod;
            $package_file =~ s/::/\//g;

            require "$package_file.pm";
        };

        next if $@;

        next unless grep { $base_obj_package eq $_ } @{mro::get_linear_isa($mod)};
        $self->generate_table_from_module( $name2table, $mod );
    }

    #
    # the following sql is always run. its a bit bootstrappy
    #
    my @sql = (
        [$self->create_object_index_sql],
        [$self->create_table_defs_sql],
        [$self->create_table_versions_sql],
        );
    # $name2table->{ObjectIndex} = $self->create_object_index_sql;
    # $name2table->{TableDefs} = $self->create_table_defs_sql;
    # $name2table->{TableVersions} = $self->create_table_versions_sql;
    push @sql, $self->tables_sql_updates( $name2table );

    @sql;
}

sub tables_sql_updates {
    my ($self, $name2table) = @_;

    my $store = $self->store;

    my @sql;
    for my $table_name (keys %$name2table) {
        my $create = $name2table->{$table_name};

        my $needs_new_table = 1;

        my( $has_table ) = $store->query_line( $store->show_tables_like($table_name) );
        if ($has_table) {
            #
            # if the table exists check if it needs an update
            #
            my @olds = $self->abridged_columns_for_table( $table_name );

            #table exists, otherwise query_do would have failed
            $needs_new_table = 0;

            my $old_columns = Set::Scalar->new;
            my %old_columns;
            for my $pair (@olds) {
                my ($name, $def) = @$pair;
                $old_columns{$name} = $def;
                $old_columns->insert( "$name $def" );
            }

            # extract and compare the columns
            my @news = $self->abridged_columns_from_create_string( $create );

            my $new_columns = Set::Scalar->new;
            my %new_columns;
            for my $col (@news) {
                my ($name, $def) = @$col;
                $new_columns{$name} = $def;
                $new_columns->insert( "$name $def" );
            }

            my $signatures_uniq_to_new = $new_columns->difference($old_columns);
            my $signatures_uniq_to_old = $old_columns->difference($new_columns);
            my %seen;
            for my $col (@$signatures_uniq_to_new) {
                # columns to add or change
                my ($col_name, $col_def) = split /\s+/, $col, 2;
                $seen{$col_name}++;

                # this column is changed
                if ($old_columns{$col_name}) {
                    # update the column. is a list. for example sqlite needs more than one sql commands
                    # to change a column
                    my @update_sql = $self->change_column( $table_name, $col_name, $col_def );
                    push @sql, map { [$_] } @update_sql;
                }
                else {
                    #this column is new
                    my @new_sql = $self->new_column( $table_name, $col_name, $col_def );
                    push @sql, map { [$_] }@new_sql;
                }
            }

            for my $col (@$signatures_uniq_to_old) {
                # columns to archive
                my ($col_name, $col_def) = split /\s+/, $col, 2;
                next if $seen{$col_name};
                my @new_sql = $self->archive_column( $table_name, $col_name, $col_def );
                push @sql, map { [$_] }@new_sql;

            }
        }
        
        if ($needs_new_table) {
            push @sql, [$create];
        }
    }

    @sql;
}

1;
