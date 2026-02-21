package Yote::SQLObjectStore::BaseObj;

use 5.16.0;
use warnings;

no warnings 'uninitialized';

use base 'Yote::SQLObjectStore::BaseStorable';

sub new {
    my $pkg = shift;
    my %args = @_;
    # in this case datatype is table
    my $obj = $pkg->SUPER::new( %args );

    if ($obj->has_first_save) {
        $obj->_load;
    } else {
        my $initial = $args{initial_vals} || {};
        my $cols = $obj->cols;
        for my $col (keys %$cols) {
            if (my $val = $initial->{$col}) {
                $obj->set( $col, $val );
            } else {
                my $store = $obj->store;
                my $type = $cols->{$col};
                if ($type =~ /^\*HASH\</ ) {
                    $obj->set( $col, $store->new_hash( $type ));
                }
                elsif ($type =~ /^\*ARRAY_/ ) {
                    $obj->set( $col, $store->new_array( $type ));
                }
            }
        }
        $obj->_init;
    }
    return $obj;
}


#
# columns as a hash of column name -> "SQL type" ||  { type => "SQL type", ... extra indexing stuff i guess? }
#
sub cols {
    my $me = shift;
    my $pkg = ref($me) ? ref($me) : $me;
    no strict 'refs';
    return {%{"${pkg}::cols"}};
}

# returns column names, alphabetically sorted
sub col_names {
    my $cols = shift->cols;
    return sort keys %$cols;
}

# returns the value type for the given column name
sub value_type {
    my ($me, $name) = @_;
    my $cols = $me->cols;
    return $cols->{$name};
}


# return table name, which is the reverse of 
# the package path (most specific first)
# plus any suffix parts
sub table_name {
    my ($self, @suffix) = @_;
    my $pkg = ref($self) || $self;
    no strict 'refs';
    my $name = ${"${pkg}::table"};
    return $name if $name;
    my (@parts) = reverse split /::/, $pkg;
    return join( "_", @parts, @suffix );
}

#
# Stub methods to override
#
sub _init {
    
}

sub _load {}

sub fields {
    return [sort keys %{shift->cols}];
}

sub save_sql {
    my ($self) = @_;
    
    my $id = $self->id;
    my $data = $self->data;
    my $table = $self->table_name;
    my @col_names = $self->col_names;

    my ($sql);

    my @qparams = map { $data->{$_} } @col_names;
    if( $self->has_first_save ) {
        $sql = "UPDATE $table SET ".
            join(',',  map { "$_=?" } @col_names ).
            " WHERE id=?";
        push @qparams, $id;
    }
    else {
        $sql = "INSERT INTO $table (".
            join(',', 'id', @col_names).") VALUES (".
            join(',', ('?') x (1+@col_names) ).
           ")";
        unshift @qparams, $id;
    }
    return [$sql, @qparams];
}

sub set {
    my ($self,$field,$value) = @_;

    # check the col
    my $cols = $self->cols;
    my $def = $cols->{$field};

    die "No field '$field' in ".ref($self) unless $def;

    my $store = $self->store;

    my ($item, $field_value) = $store->xform_in_full( $value, $def );

    my $data = $self->data;

    my $dirty = $data->{$field} ne $field_value;

    $data->{$field} = $field_value;

    if ($dirty) {
        $self->dirty;
    }

    return $item;    
}

sub get {
    my ($self,$field,$default) = @_;

    my $cols = $self->cols;
    my $def = $cols->{$field};

    die "No field '$field' in ".ref($self) unless $def;

    my $data = $self->data;

    if ((! exists $data->{$field}) and defined($default)) {
	return $self->set($field,$default);
    }

    return $self->store->xform_out( $data->{$field}, $def );
} #get


=head2 find_where( $store, %criteria )

Class method to find objects matching all criteria.

 my @admins = MyApp::User->find_where($store,
     status => 'active',
     role   => 'admin'
 );

=cut

sub find_where {
    my ($class, $store, %criteria) = @_;
    return $store->find_where($class, %criteria);
}

sub AUTOLOAD {
    my( $s, @args ) = @_;
    my $func = our $AUTOLOAD;
    if ( $func =~ /:set_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, $val ) = @_;
            $self->set( $fld, $val );
        };
        use strict 'refs';
        goto &$AUTOLOAD;
    }
    elsif( $func =~ /:get_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, $init_val ) = @_;
            $self->get( $fld, $init_val );
        };
        use strict 'refs';
        goto &$AUTOLOAD;
    }
    elsif( $func =~ /:find_by_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $class, $store, $value ) = @_;
            return $store->find_by( $class, $fld, $value );
        };
        use strict 'refs';
        goto &$AUTOLOAD;
    }
    elsif( $func =~ /:find_all_by_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $class, $store, $value, %options ) = @_;
            return $store->find_all_by( $class, $fld, $value, %options );
        };
        use strict 'refs';
        goto &$AUTOLOAD;
    }
    elsif( $func =~ /:find_first_by_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $class, $store, $value ) = @_;
            my @results = $store->find_all_by( $class, $fld, $value, limit => 1 );
            return $results[0];
        };
        use strict 'refs';
        goto &$AUTOLOAD;
    }
    elsif( $func !~ /:DESTROY$/ ) {
        die "Yote::ObjectStore::Obj::$func : unknown function '$func'.";
    }

} #AUTOLOAD

1;
