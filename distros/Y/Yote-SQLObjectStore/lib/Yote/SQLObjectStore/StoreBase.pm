package Yote::SQLObjectStore::StoreBase;

use 5.16.0;
use warnings;

no warnings 'uninitialized';

use Yote::SQLObjectStore::TiedArray;
use Yote::SQLObjectStore::TiedHash;

use Scalar::Util qw(weaken blessed);
use Time::HiRes qw(time);

use vars qw($VERSION);

my $QUERY_DEBUG = 0;

$VERSION = '2.06';

=head1 NAME

Yote::SQLObjectStore::StoreBase - Base class for SQL-backed object stores

=head1 SYNOPSIS

 use Yote::SQLObjectStore;

 my $store = Yote::SQLObjectStore->new( 'SQLite',
     BASE_DIRECTORY => '/path/to/data',
     root_package   => 'MyApp::Root',
 );

 # Generate tables for your object classes
 $store->make_all_tables(@INC);

 $store->open;

 my $root = $store->fetch_root;

 my $user = $store->new_obj( 'MyApp::User', name => 'Alice' );
 $root->get_users->{alice} = $user;

 $store->save;

=head1 DESCRIPTION

StoreBase provides the core functionality for SQL-backed object stores,
supporting both SQLite and MariaDB backends.

=head1 METHODS

=cut

sub new {
    my( $pkg, %args ) = @_;

    my $dbh = $pkg->connect_sql( %args );

    my $store = bless {
        DBH          => $dbh,
        DIRTY        => {},
        WEAK         => {},
        OPTIONS      => \%args,
        ROOT_PACKAGE => $args{root_package},
        STATEMENTS   => {},
    }, $pkg;

    $store->make_table_manager;

    return $store;

}

sub open {
    my $self = shift;
    $self->fetch_root;
    return $self;
}

sub statements {
    return shift->{STATEMENTS};
}

sub dbh {
    return shift->{DBH};
}

sub get_table_manager {
    return shift->{TABLE_MANAGER};
}

sub store_obj_data_to_sql {
    my ($self, $ref ) = @_;

    my $obj = _yoteobj($ref);
    my (@queries) = $obj->save_sql;
    for my $q (@queries) {
        my ($update_obj_table_sql, @qparams) = @$q;
        $self->query_do( $update_obj_table_sql, @qparams );
    }
}

sub record_count {
    my $self = shift;

    my ($count) = $self->query_line( "SELECT count(*) FROM ObjectIndex WHERE live=1" );

    return $count;
}

sub make_all_tables {
    my ($self, @INC_PATH) = @_;
    my @sql = $self->make_all_tables_sql(@INC_PATH);

    $self->start_transaction;
    for my $s (@sql) {
        my ($query, @qparams) = @$s;
        $self->query_do( $query, @qparams );
    }
    $self->commit_transaction;
}

sub make_all_tables_sql {
    my ($self, @INC_PATH) = @_;
    my $manager = $self->get_table_manager;
    my @sql = $manager->generate_tables_sql( $self->base_obj, @INC_PATH );
    return @sql;
}

sub check_table {
    my ($self, $table_label) = @_;
    my $manager = $self->get_table_manager;
    my $name2table = {};
    $manager->generate_reference_table( $name2table, $table_label );
    my @sql = $manager->tables_sql_updates( $name2table );

    $self->start_transaction;
    for my $s (@sql) {
        my ($query, @qparams) = @$s;
        $self->query_do( $query, @qparams );
    }
    $self->commit_transaction;
}

sub _package_is_baseobj {
    my $pkg = shift;

    my ($find, %seen);

    $find = sub {
        my $p = shift;
        return if $seen{$p}++;

        no strict 'refs';
        if (my $isa = \@{"${p}::ISA"}) {
            $find->( $_ ) foreach @$isa;
        }
    };
    
    $find->($pkg);

    return $seen{'Yote::SQLObjectStore::BaseObj'};
}

sub new_obj($*@) {
    my ($self, $pkg, %args) = @_;

    my $package_file = $pkg;
    $package_file =~ s/::/\//g;

    require "$package_file.pm";

    if (!_package_is_baseobj($pkg)) {
        die "'$pkg' is not a Yote::SQLObjectStore::BaseObj descendant";
    }

    # check to make sure this descends from
    # Yote::SQLObjectStore::BaseObj

    

    my $table = $pkg->table_name;

    my $id = $self->next_id( $table, $pkg );

    $self->check_table($pkg);

    my $obj_data = {};
    my $obj = $pkg->new(
        ID    => $id,

        data  => $obj_data,
        store => $self,
        table => $table,
        type  => "*$pkg",

        initial_vals  => \%args,
        );

    $self->weak( $obj );
    $self->dirty( $obj );

    if (%args) {
        my $cols = $pkg->cols;

        for my $input_field (keys %args) {
            if ( my $coldef = $cols->{$input_field} ) {
                $obj_data->{$input_field} = $self->xform_in( $args{$input_field}, $coldef );
            } else {
                die "'$input_field' does not exist for object with package $pkg";
            }
        }
    }

    return $obj;
}

sub _new_thing {
    my ($self, $type, @args) = @_;
    if ($type =~ /^\*?ARRAY_/) {
        return $self->new_array( $type, @args );
    }
    elsif ($type =~ /^\*?HASH<\d+>_/) {
        return $self->new_hash( $type, @args );
    }
    my ($pkg) = ( $type =~ /^\*?(.*)/);

    return $self->new_obj( $pkg, @args );
}

sub new_hash {
    my ($self, $type, %args) = @_;

    my ($value_type) = ($type =~ /^\*?HASH<\d+>_(.*)/);

    die "Cannot create hash of type '$type'" unless $value_type;

    my $id = $self->next_id( $type );

    $self->check_table( $type );

    my $hash = Yote::SQLObjectStore::TiedHash->tie( $self, $id, $type );
    my $tied = _yoteobj( $hash );
    $self->weak( $tied );
    $self->dirty( $tied );

    for my $key (keys %args) {
        $hash->{$key} = $args{$key};
    }

    return $hash;
}

sub has_id {
    my ($self,$ref) = @_;
    my $r = ref $ref;
    return (tied @$ref)->id if $r eq 'ARRAY';
    return (tied %$ref)->id if $r eq 'HASH';
    return blessed $ref && $ref->can('id') && $ref->id;
}

sub _yoteobj {
    my $ref = shift;
    my $r = ref $ref;
    return tied @$ref if $r eq 'ARRAY';
    return tied %$ref if $r eq 'HASH';
    return $ref;
}

sub new_array {
    my ($self, $type, @vals) = @_;

    my ($value_type) = ($type =~ /^\*?ARRAY_(.*)/);

    die "Cannot create array of type '$type'" unless $value_type;

    my $id = $self->next_id( $type );
    $self->check_table( $type );

    my $array = Yote::SQLObjectStore::TiedArray->tie( $self, $id, $type );
    my $tied = _yoteobj( $array );
    $self->weak( $tied );
    $self->dirty( $tied );

    push @$array, @vals;
    return $array;
}


# given a thing and its type definition
# return its internal value which will
# either be an object id or a string value
sub xform_in {
    my $self = shift;
    my $encoded = $self->xform_in_full(@_);
    return $encoded;
}

sub xform_in_full {
    my ($self, $value, $type_def) = @_;

    my $ref = ref( $value );

    # check if type is right
    my $field_value;
    if ($type_def =~ /^\*/ && $value) {
        my $obj = _yoteobj( $value );
        unless ($self->check_type( $obj, $type_def )) {
            my $checked_type = (ref $obj && $obj->{type}) || 'scalar value';
            die "incorrect type '$checked_type' for '$type_def' ($obj)";
        }
die "xform_in_full: expected object for type '$type_def' but got '$value'" unless $obj;
        $field_value = $obj->id;
    } else {
        $field_value = $value;
    }
    return $value, $field_value;
}

# given an internal value and definition
# return the object or string value it represents
# if it is a reference with a 0 id, return 0 indicating
# not here
sub xform_out {
    my ($self, $value, $def) = @_;

    if( $def !~ /^\*/ || $value == 0 ) {
        return $value;
    }

    # other option is a reference and the value is an id

    return $self->fetch( $value );
}


sub root_id {
    1; #always 1
}

=head2 fetch_root()

Returns the root node of the object store.

=cut

sub fetch_root {
    my $self = shift;

    my $root_id = $self->root_id;

    my $root = $self->fetch( $root_id );
    return $root if $root;

    $root = $self->new_obj( $self->{ROOT_PACKAGE} );
    $self->save;
    return $root;
} #fetch_root


=head2 save (obj)

If given an object, saves that object.

If not given an object, saves all objects marked dirty.

=cut

sub save {

    my ($self,$obj) = @_;
    my @dirty = $obj ? ($obj) : values %{$self->{DIRTY}};

    # start transaction
    $self->start_transaction;
    for my $item (@dirty) {
        $self->store_obj_data_to_sql( $item );
    }
    %{$self->{DIRTY}} = ();

    $self->commit_transaction;

    # end transaction
    return 1;
} #save

=head2 fetch( $id )

Returns the object with the given id.

=cut

sub fetch {
    my ($self, $id) = @_;
    my $obj;
    if (exists $self->{DIRTY}{$id}) {
        $obj = $self->{DIRTY}{$id};
    } else {
        $obj = $self->{WEAK}{$id};
    }

    return $obj if $obj;

    $obj = $self->fetch_obj_from_sql( $id );

    return undef unless $obj;

    $self->weak( $obj );

    return $obj;
}

#
# given a from_id referencing a container, and a key or index to that
# container, return one of the following
#   0, undef <-- takes a scalar but has no value
#   0, 'value'  <--- takes a scalar and has a value
#   ref_id, undef, type <-- has a reference with the given type
#   0, undef, type  <-- has no reference stored, accepts the given type
#
sub _fetch_refid_or_val {
    my ($self, $from_id, $key_or_index) = @_;

    # check the cache first
    my $obj = $self->in_cache($from_id);
    if ($obj) {
        my $ref = _yoteobj( $obj );
        my $value_type = $ref->value_type;
        if (ref $ref eq 'Yote::SQLObjectStore::TiedArray') {
            if ($value_type =~ /^\*/) {
                return $ref->{data}[$key_or_index], undef, $value_type;
            }
            return 0, $ref->get( $key_or_index );
        }
        elsif (ref $ref eq 'Yote::SQLObjectStore::TiedHash') {
            if ($value_type =~ /^\*/) {
                return $ref->{data}{$key_or_index}, undef, $value_type;
            }
            return 0, $ref->get( $key_or_index );
        }
        my $field = $ref->cols->{$key_or_index};
        if ($field =~ /^\*/) {
            return $ref->{data}{$key_or_index}, undef, $obj->value_type($key_or_index);
        }
        return 0, $ref->get( $key_or_index );
    }

    # its not in the cache, so load from store
    my $table_manager = $self->get_table_manager;
    my ($tablehandle,$objectclass) = $self->query_line( "SELECT tablehandle,objectclass FROM ObjectIndex WHERE id=?", $from_id );
    my $table = $table_manager->label_to_table( $tablehandle );
    if ($tablehandle =~ /^\*ARRAY_(.*)/) {
        my $type = $1;
        my $is_ref = $type =~ /^\*/;
        my ($val) = $self->query_line( "SELECT val FROM $table WHERE id=? AND idx=?", $from_id, $key_or_index );
        if ($is_ref) {
            # a reference
            return $val, undef, $type;
        }
        return 0, $val, 'ARRAY';
    }
    elsif ($tablehandle =~ /^\*HASH\<\d+\>_(.*)/) {
        my $type = $1;
        my $is_ref = $type =~ /^\*/;

        my ($val) = $self->query_line( "SELECT val FROM $table WHERE id=? AND hashkey=?", $from_id, $key_or_index );
        if ($is_ref) {
            # val is a reference in this case
            return $val, undef, $type;
        }
        return 0, $val, 'HASH';
    }

    # load the object class
    my $package_file = $objectclass;
    $package_file =~ s/::/\//g;

    require "$package_file.pm";
    die "Invalid Column Name for yote '$key_or_index'" if $key_or_index =~ /[^-_a-zA-Z0-9]/;
    my ($val) = $self->query_line( "SELECT $key_or_index FROM $table WHERE id=?", $from_id );

    my $cols = $objectclass->cols;
    if ((my $type = $cols->{$key_or_index}) =~ /^\*/) {
        # a reference
        return $val, undef, $type;
    }
    return 0, $val;
}

# get a path from the data structure given a forward slash delimited string
# plus any additional path elements
sub fetch_string_path {
    my ($self, $path, @rest) = @_;
    my @path = ((grep { $_ ne '' } split '/', $path), @rest);
    $self->fetch_path(@path);
}

# fetch item from the root following that path
sub fetch_path {
    my ($self, @path) = @_;
    my $from_id = $self->root_id;
    return $self->_fetch_rel_path( $from_id, @path );
}

# fetch item from the root following that path
sub fetch_rel_path {
    my ($self, $item, @path) = @_;
    my $from_id = _yoteobj($item)->id;
    return $self->_fetch_rel_path( $from_id, @path );
}


# fetch item from the item at the given id following that path
sub _fetch_rel_path {
    my ($self, $from_id, @path) = @_;


    while (defined(my $segment = shift @path)) {
        my ($ref_id,$val) = $self->_fetch_refid_or_val( $from_id, $segment );
        if ($ref_id) {
            $from_id = $ref_id;
        } else {
            die "invalid path '".join('/',@path)."', '$segment' is not a reference" if @path;
            return $val;
        }
    }
    return $self->fetch( $from_id );
}

sub has_path {
    my ($self, @path) = @_;

    my $from_id = $self->root_id;
    while (defined(my $segment = shift @path)) {
        my ($ref_id,$val) = $self->_fetch_refid_or_val( $from_id, $segment );
        if ($ref_id) {
            $from_id = $ref_id;
        } else {
            return undef if @path;
            return defined $val;
        }
    }
    return defined $from_id;
}

sub ensure_paths {
    my ($self, @paths) = @_;
    $self->start_transaction();
    $self->{temp_refs} = {};
    my $endpoint;
    eval {
        for my $path (@paths) {
            $endpoint = $self->_ensure_path( ref $path ? @$path : $path );
        }
    };
    if (my $err = $@) {
        for my $id (keys %{$self->{temp_refs}}) {
            delete $self->{DIRTY}{$id};
            delete $self->{WEAK}{$id};
        }
        $self->rollback_transaction();
        die $err;
    }
    $self->commit_transaction();
    return $endpoint;
}

sub ensure_path {
    my ($self, @path) = @_;
    $self->start_transaction();
    my $endpoint;
    $self->{temp_refs} = {};
    eval {
        $endpoint = $self->_ensure_path( @path );
    };
    if (my $err = $@) {
        for my $id (keys %{$self->{temp_refs}}) {
            delete $self->{DIRTY}{$id};
            delete $self->{WEAK}{$id};
        }
        $self->rollback_transaction();
        die $err;
    }
    $self->commit_transaction();
    return $endpoint;
}

sub _convert_string_path {
    my ($str_path) = @_;
    
    my @path;
    while ($str_path =~ /^(((.*?)(^|[^\\])(\\\\)*)\/(.*))|(.+?)$/ ) {
        my $segment = $7 || $2;
        $str_path = $6;
        next unless $segment;
        my ($key_or_val, $class) = split /\|/, $segment, 2;
        if ($class) {
            push @path, [$key_or_val, $class];
        } else {
            push @path, $key_or_val;
        }
    }
    return @path;
}

# the path is a list of segments. the segments can be a string
# for a path key, or [$pathkey, class => $class, index => $index, $value => $value, key => $key]
# where 'index' is for arrays and 'key' is for hashes
sub _ensure_path {
    my ($self, @path) = @_;

    if (@path == 1 && !ref $path[0]) {
        @path = _convert_string_path( $path[0] );
    }

    # always starts from root
    my $current_ref = $self->fetch_root; 
    my $from_id = $self->root_id;

    while (my $segment = shift @path) {
        my ($key, $cls_or_val) = ref $segment ? @$segment : $segment;

        die "invalid path. missing key" if ! $key;

        my ($ref_id, $val, $expected_value_type) = $self->_fetch_refid_or_val( $from_id, $key );
        if (! $expected_value_type) { # not a reference
            die "invalid path. non-reference encountered before the end" if @path;
            if (defined $cls_or_val and defined $val) {
                die "path ends in different value" if $val ne $cls_or_val;
            } 

            my $curr_obj = _yoteobj( $current_ref );
            if (defined $cls_or_val) {
                $self->{temp_refs}{$curr_obj->id} = 1;
                $curr_obj->set( $key, $cls_or_val );
                return $cls_or_val;
            }
            return $curr_obj->get( $key );
        }

        #
        # key is there, then check if its an array element that is there.
        # if there after the check, set the current from_id and loop again
        #
        if ($ref_id) {
            $from_id = $ref_id;
            $current_ref = $self->fetch( $ref_id );
            if (defined $cls_or_val and $cls_or_val ne ref $current_ref) {
                die "path exists but got type '$cls_or_val' and expected type '".ref($current_ref)."'";
            }
            next;
        }

        #
        # nothing is yet keyed to that segment, so create the thing and fill it
        #
        # the thing is attached to the current ref. is the current ref
        # an array, hash or class?
        #
        my $curr_obj = _yoteobj( $current_ref );

        $cls_or_val //= $expected_value_type;

        if ($cls_or_val eq '*') {
            die "invalid path. wildcard slot requires an object type be given when placing into that slot";
        }

        if ($expected_value_type ne '*' and $cls_or_val ne $expected_value_type) {
            die "invalid path. incorrect type '$cls_or_val', expected '$expected_value_type'";
        }

        my $new_value;
        eval {
            $new_value = $self->_new_thing( $cls_or_val );
        };
        if ( $@ ) {
            if ($@ =~ /^Can.t locate.*in \@INC/) {
                die "invalid path '$cls_or_val' not found in @INC";
            }
            die $@;
        }
        $from_id = _yoteobj( $new_value )->id;

        #
        # install the new thing at the path reference
        #
        $curr_obj->set( $key, $new_value );
        $self->{temp_refs}{$curr_obj->id} = 1;        

        $current_ref = $new_value;
    }
    return $current_ref;
} #_ensure_path

sub del_string_path {
    my ($self, $path) = @_;
    my @path = (grep { $_ ne '' } split '/', $path);
    $self->del_path( @path );
}

sub del_path {
    my ($self, @path) = @_;

    # always starts from root
    my $current_ref  =   $self->fetch_root;
    my $from_id      =   $self->root_id;

    my $del_key = pop @path;
    my ($ref_id, $ref_type);
    while (my $key = shift @path) {
        ($ref_id, undef, $ref_type) = $self->_fetch_refid_or_val( $from_id, $key );

        die "encounterd non reference in path" unless $ref_id;
        
        $from_id = $ref_id;
    }
    my $old_val;
    $current_ref = $self->fetch( $ref_id );
    my $curr_obj = _yoteobj( $current_ref );
    $old_val = $curr_obj->get( $del_key );
    $curr_obj->set( $del_key, undef );
    $old_val;
}

sub set_rel_path {
    my ($self, $item, @path) = @_;
    my $from_id = _yoteobj($item)->id;
    return $self->_set_path_trans( $from_id, @path );
}

sub set_path {
    my ($self, @path) = @_;
    return $self->_set_path_trans( $self->root_id, @path );
}

sub _set_path_trans {
    my ($self, $from_id, @path) = @_;
    if (@path < 2) {
        die "set_path. path '@path' not long enough to set";
    }
    $self->start_transaction();
    my $endpoint;
    $self->{temp_refs} = {};
    eval {
        $endpoint = $self->_set_path( $from_id, @path );
    };
    if (my $err = $@) {
        for my $id (keys %{$self->{temp_refs}}) {
            delete $self->{DIRTY}{$id};
            delete $self->{WEAK}{$id};
        }
        $self->rollback_transaction();
        die $err;
    }
    $self->commit_transaction();
    return $endpoint;
}

sub _set_path {
    my ($self, $from_id, @path ) = @_;
    
    my $set_value   =  pop @path;
    my $insert_key  =  pop @path;

    # always starts from root
    while (my $key = shift @path) {
        my ($ref_id) = $self->_fetch_refid_or_val( $from_id, $key );

        #
        # key is there, then check if its an array element that is there.
        # if there after the check, set the current from_id and loop again
        #
        die "encounterd non reference in path" unless $ref_id;

        $from_id = $ref_id;
    }
    my $current_ref = $self->fetch( $from_id );
    my $curr_obj = _yoteobj( $current_ref );
    $curr_obj->set( $insert_key, $set_value );
    return $set_value;
}

sub set_path_if_not_exist {
    my ($self, @path) = @_;
    if (@path < 2) {
        die "set_path. path '@path' not long enough to set";
    }
    $self->start_transaction();
    my $endpoint;
    $self->{temp_refs} = {};
    eval {
        $endpoint = $self->_set_path_if_not_exist( @path );
    };
    if (my $err = $@) {
        for my $id (keys %{$self->{temp_refs}}) {
            delete $self->{DIRTY}{$id};
            delete $self->{WEAK}{$id};
        }
        $self->rollback_transaction();
        die $err;
    }
    $self->commit_transaction();
    return $endpoint;
}

sub _set_path_if_not_exist {
    my ($self, @path ) = @_;
    
    my $set_value   =  pop @path;
    my $insert_key  =  pop @path;

    if ($self->has_path( @path, $insert_key )) {
        return $self->fetch_path( @path, $insert_key );
    }

    # always starts from root
    my $current_ref  =   $self->fetch_path( @path );
    my $curr_obj = _yoteobj( $current_ref );
    my $val = ref $set_value eq 'CODE' ? $set_value->() : $set_value ;
    $curr_obj->set( $insert_key, $val );
    return $val;
}


=head2 is_dirty(obj)

Returns true if the object is a base storable object that needs saving.

=cut

sub is_dirty {
    my ($self,$ref) = @_;
    my $obj = _yoteobj($ref);
    unless ( blessed $obj and $obj->isa('Yote::SQLObjectStore::BaseStorable')
             || $obj->isa('Yote::SQLObjectStore::TiedArray')
             || $obj->isa('Yote::SQLObjectStore::TiedHash') )
    {
        warn "checked if non base value is dirty";
        return;
    }

    return defined( $self->{DIRTY}{$obj->id} );
}

sub in_cache {
    my ($self, $id) = @_;
    return $self->{DIRTY}{$id} || $self->{WEAK}{$id};
}

# make a weak reference of the reference
# and save it by id
sub weak {
    my ($self,$ref) = @_;
    my $obj = _yoteobj($ref);
    my $id = $obj->id;
    my $cache_obj = $obj->cache_obj;
    $self->{WEAK}{$id} = $cache_obj;

    weaken( $self->{WEAK}{$id} );
}

#
# make sure the given obj has a weak
# reference, and is stored by the id
# in the DIRTY cache
#
sub dirty {
    my ($self,$ref) = @_;
    my $obj = _yoteobj($ref);
    return unless blessed $obj;
    my $id = $obj->id;
    unless ($self->{WEAK}{$id}) {
	$self->weak($obj);
    }
    my $target = $self->{WEAK}{$id};

    my @dids = keys %{$self->{DIRTY}};

    $self->{DIRTY}{$id} = $target;
} #dirty

sub next_id {
    my ($self, $table_handle, $objectclass) = @_;
    return $self->insert_get_id( "INSERT INTO ObjectIndex (tablehandle,objectclass,live) VALUES (?,?,1)", $table_handle, $objectclass );
}


# --------- DB FUNS -------

sub sth {
    my ($self, $query ) = @_;

    my $stats = $self->statements;
    my $dbh   = $self->dbh;
    my $sth   = ($stats->{$query} //= $dbh->prepare( $query ));

    $sth or die "$query : ". $dbh->errstr;

    return $sth;
}

sub insert_get_id {
    my ($self, $query, @qparams ) = @_;
    my $dbh = $self->dbh;
    print STDERR "QUERY INS: $query [@qparams]\n" if $QUERY_DEBUG;
    my $sth = $self->sth( $query );
    my $res = $sth->execute( @qparams );
    if (!defined $res) {
        die $sth->errstr;
    }
    my $id = $dbh->last_insert_id;
    return $id;
}

sub query_do {
    my ($self, $query, @qparams ) = @_;
    my $dbh = $self->dbh;
    print STDERR "QUERY: $query [@qparams]\n" if $QUERY_DEBUG;
    my $sth = $dbh->prepare( $query );
    if (!defined $sth) {
        die "query_do prepare failed: " . $dbh->errstr . " (query: $query)";
    }
    my $res = $sth->execute( @qparams );
    if (!defined $res) {
        die "query_do execute failed: " . $sth->errstr . " (query: $query)";
    }
    return $sth;
}

sub query_line {
    my ($self, $query, @qparams ) = @_;
    print STDERR "QUERY LINE: $query [@qparams]\n" if $QUERY_DEBUG;
    my $sth = $self->sth( $query );
    my $res = $sth->execute( @qparams );
    if (!defined $res) {
        die $sth->errstr;
    }
    my @ret = $sth->fetchrow_array;
    return @ret;
}

sub print_query_output {
    my ($self, $query, @qparams ) = @_;
    my $sth = $self->sth( $query );
print STDERR "QUERY PQO: $query [@qparams]\n" if $QUERY_DEBUG;
    my $res = $sth->execute( @qparams );
    if (!defined $res) {
        die $sth->errstr;
    }
}

sub apply_query_array {
    my ($self, $query, $qparams, $eachrow_fun ) = @_;
print STDERR "QUERY AQA: $query [@$qparams]\n" if $QUERY_DEBUG;
    my $sth = $self->sth( $query );
    my $res = $sth->execute( @$qparams );
    if (!defined $res) {
        die $sth->errstr;
    }
    while ( my (@array) = $sth->fetchrow_array ) {
        $eachrow_fun->(@array);
    }
}

# --------- FINDER METHODS -------

=head2 _validate_finder_field( $class, $field )

Validates that a field exists in the class and is a scalar (searchable) column.
Dies with descriptive error if validation fails.

=cut

sub _validate_finder_field {
    my ($self, $class, $field) = @_;

    # Validate field name to prevent SQL injection
    die "Invalid field name '$field'" if $field =~ /[^_a-zA-Z0-9]/;

    my $cols = $class->cols;

    die "Field '$field' does not exist in $class"
        unless exists $cols->{$field};

    my $type = $cols->{$field};
    die "Cannot search by reference field '$field' (type: $type)"
        if $type =~ /^\*/;

    return 1;
}

=head2 find_by( $class, $field, $value )

Finds a single object of the given class where field equals value.
Returns the object or undef if not found.

 my $user = $store->find_by('MyApp::User', 'email', 'bob@example.com');

=cut

sub find_by {
    my ($self, $class, $field, $value) = @_;

    $self->_validate_finder_field($class, $field);

    my $table = $class->table_name;
    my ($id) = $self->query_line(
        "SELECT id FROM $table WHERE $field = ? LIMIT 1", $value
    );

    return undef unless $id;
    return $self->fetch($id);
}

=head2 find_all_by( $class, $field, $value, %options )

Finds all objects of the given class where field equals value.
Returns a list of objects (possibly empty).

Options:
  limit    => N           - Limit results to N objects
  offset   => N           - Skip first N results
  order_by => 'field ASC' - Sort results (field name validated)

 my @users = $store->find_all_by('MyApp::User', 'status', 'active',
     order_by => 'name ASC',
     limit => 10
 );

=cut

sub find_all_by {
    my ($self, $class, $field, $value, %options) = @_;

    $self->_validate_finder_field($class, $field);

    my $table = $class->table_name;
    my $sql = "SELECT id FROM $table WHERE $field = ?";

    # Add ORDER BY if specified
    if (my $order = $options{order_by}) {
        my ($order_field) = ($order =~ /^(\w+)/);
        $self->_validate_finder_field($class, $order_field) if $order_field;
        $sql .= " ORDER BY $order";
    }

    # Add LIMIT/OFFSET
    if (my $limit = $options{limit}) {
        $sql .= " LIMIT " . int($limit);
    }
    if (my $offset = $options{offset}) {
        $sql .= " OFFSET " . int($offset);
    }

    my @objects;
    $self->apply_query_array($sql, [$value], sub {
        my ($id) = @_;
        push @objects, $self->fetch($id);
    });

    return @objects;
}

=head2 find_where( $class, %criteria )

Finds objects matching all criteria (AND logic).
Returns a list of objects, or a single object if _single => 1.

Special keys in criteria:
  _limit    => N           - Limit results
  _offset   => N           - Skip first N results
  _order_by => 'field ASC' - Sort results
  _single   => 1           - Return single object or undef

 my @admins = $store->find_where('MyApp::User',
     status => 'active',
     role   => 'admin',
     _order_by => 'name ASC'
 );

 my $user = $store->find_where('MyApp::User',
     email => 'bob@example.com',
     _single => 1
 );

=cut

sub find_where {
    my ($self, $class, %criteria) = @_;

    # Extract special options
    my $limit    = delete $criteria{_limit};
    my $offset   = delete $criteria{_offset};
    my $order_by = delete $criteria{_order_by};
    my $single   = delete $criteria{_single};

    # Validate all fields
    for my $field (keys %criteria) {
        $self->_validate_finder_field($class, $field);
    }

    my $table = $class->table_name;
    my @fields = sort keys %criteria;
    my @values = map { $criteria{$_} } @fields;

    my $where = join(' AND ', map { "$_ = ?" } @fields);
    my $sql = "SELECT id FROM $table WHERE $where";

    if ($order_by) {
        my ($order_field) = ($order_by =~ /^(\w+)/);
        $self->_validate_finder_field($class, $order_field) if $order_field;
        $sql .= " ORDER BY $order_by";
    }

    if ($single) {
        $sql .= " LIMIT 1";
        my ($id) = $self->query_line($sql, @values);
        return undef unless $id;
        return $self->fetch($id);
    }

    if ($limit) {
        $sql .= " LIMIT " . int($limit);
    }
    if ($offset) {
        $sql .= " OFFSET " . int($offset);
    }

    my @objects;
    $self->apply_query_array($sql, \@values, sub {
        my ($id) = @_;
        push @objects, $self->fetch($id);
    });

    return @objects;
}

sub start_transaction {
    my $self = shift;
    return if $self->{in_transaction};
    if ($self->{LOCKER}) {
        $self->{LOCKER}->lock;
    }
    $self->_start_transaction;
    $self->{in_transaction} = 1;
}
sub commit_transaction {
    my $self = shift;
    return unless $self->{in_transaction};
    $self->_commit_transaction;
    $self->{in_transaction} = 0;
    if ($self->{LOCKER}) {
        $self->{LOCKER}->unlock;
    }
}
sub rollback_transaction {
    my $self = shift;
    return unless $self->{in_transaction};
    $self->_rollback_transaction;
    $self->{in_transaction} = 0;
    if ($self->{LOCKER}) {
        $self->{LOCKER}->unlock;
    }
}

sub obj_info {
    my ($self, $id) = @_;
    my ($handle,$class) = $self->query_line(
        "SELECT tablehandle, objectclass FROM ObjectIndex WHERE id=?",
        $id );
    return $handle, $class;
}

sub fetch_obj_from_sql {
    my ($self, $id) = @_;

    my ($handle,$class) = $self->obj_info( $id );

    return undef unless $handle;

    if ($handle =~ /^\*HASH<\d+>_.*/) {
        return Yote::SQLObjectStore::TiedHash->tie( $self, $id, $handle );
    }
    elsif ($handle =~ /^\*ARRAY_.*/) {
        return Yote::SQLObjectStore::TiedArray->tie( $self, $id, $handle );
    }

    # otherwise is an object, so grab its data

    my $table = $handle;

    my $package_file = $class;
    $package_file =~ s/::/\//g;

    require "$package_file.pm";

    my $cols = $class->cols;
    my @cols = keys %$cols;

    my $sql = "SELECT ".join(',', @cols )." FROM $table WHERE id=?";

    my (@ret) = $self->query_line( $sql, $id );

    my $obj = $class->new(
        ID => $id,

        data => { map { $cols[$_] => $ret[$_] } (0..$#cols) },
        has_first_save => 1,
        store => $self,
        table => $table,
        type  => "*$class",

        );

    return $obj;
}

sub check_type {
    my ($self, $value, $type_def) = @_;
    my $obj = _yoteobj($value);

    ! $obj
        or
        $obj->isa( $self->base_obj ) ||
        $obj->isa( 'Yote::SQLObjectStore::TiedArray' ) ||
        $obj->isa( 'Yote::SQLObjectStore::TiedHash' )
        and
        $obj->is_type( $type_def );
}

sub lock {
    my ($self, $tag) = @_;
    $tag =~ s/'//gs;
    my ($res) = $self->query_line( "SELECT GET_LOCK(?,1)", $tag );
    if (! defined $res) {
        warn "lock failed when called for lock tag '$tag'";
    }
    return $res;
}

sub unlock {
    my ($self, $tag) = @_;
    $tag =~ s/'//gs;
    my ($res) = $self->query_line( "SELECT RELEASE_LOCK(?,1)", $tag );
    if (! defined $res) {
        warn "unlock failed when called for unheld lock tag '$tag'";
    }
    return $res;
}

"BUUG";
