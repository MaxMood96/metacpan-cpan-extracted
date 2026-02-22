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
# columns as a hash of column name -> type definition
# scalar types use ANSI SQL standard types (mapped to native types per backend)
# reference types start with *
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


=head1 COLUMN TYPES

Object fields are declared via the package-level C<%cols> hash, mapping
column names to type definitions.

    package MyApp::User;
    use base 'Yote::SQLObjectStore::SQLite::Obj';

    our %cols = (
        name    => 'VARCHAR(100)',
        bio     => 'TEXT',
        age     => 'INTEGER',
        score   => 'DECIMAL(5,2)',
        active  => 'BOOLEAN',
        avatar  => '*MyApp::Image',
        tags    => '*ARRAY_VARCHAR(50)',
        friends => '*ARRAY_*MyApp::User',
        prefs   => '*HASH<256>_TEXT',
    );

There are two categories of column types: B<scalar types> for storing
values directly in the object's table, and B<reference types> for
storing references to other objects or to collection objects (arrays
and hashes).

=head2 Scalar Types

Scalar types use ANSI SQL standard names. Each backend automatically
translates these to native database types via C<map_type> in the
backend's TableManager, so the same C<%cols> definition works across
SQLite, MariaDB, and PostgreSQL.

=head3 Text

    TEXT            Variable-length text, no length limit
    VARCHAR(N)      Variable-length text, max N characters

C<TEXT> is the general-purpose string type. Use C<VARCHAR(N)> when you
want to express a maximum length. MariaDB and PostgreSQL enforce the
limit; SQLite preserves the declaration but treats it as TEXT affinity.

=head3 Numeric

    INTEGER         Standard integer (4 bytes on most backends)
    BIGINT          Large integer (8 bytes)
    SMALLINT        Small integer (2 bytes)
    FLOAT           Single-precision floating point
    DOUBLE          Double-precision floating point
    DECIMAL(M,D)    Exact decimal with M total digits, D after the decimal point

SQLite maps all integer types to C<INTEGER> and all floating-point types
to C<REAL>. MariaDB maps C<INTEGER> to C<INT>. PostgreSQL maps C<FLOAT>
to C<REAL> and C<DOUBLE> to C<DOUBLE PRECISION>.

=head3 Other

    BOOLEAN         True/false value
    BLOB            Binary data
    TIMESTAMP       Date and time
    DATE            Date only

SQLite maps C<BOOLEAN> to C<INTEGER> and C<TIMESTAMP>/C<DATE> to C<TEXT>.
MariaDB maps C<BOOLEAN> to C<TINYINT(1)>.
PostgreSQL maps C<BLOB> to C<BYTEA>.

=head3 Backend Type Mapping Summary

    Standard        SQLite      MariaDB         PostgreSQL
    --------        ------      -------         ----------
    TEXT            TEXT        TEXT            TEXT
    VARCHAR(N)      VARCHAR(N)  VARCHAR(N)      VARCHAR(N)
    INTEGER         INTEGER     INT             INTEGER
    BIGINT          INTEGER     BIGINT          BIGINT
    SMALLINT        INTEGER     SMALLINT        SMALLINT
    FLOAT           REAL        FLOAT           REAL
    DOUBLE          REAL        DOUBLE          DOUBLE PRECISION
    DECIMAL(M,D)    NUMERIC     DECIMAL(M,D)    DECIMAL(M,D)
    BOOLEAN         INTEGER     TINYINT(1)      BOOLEAN
    BLOB            BLOB        BLOB            BYTEA
    TIMESTAMP       TEXT        TIMESTAMP       TIMESTAMP
    DATE            TEXT        DATE            DATE

=head2 Reference Types

Reference types start with C<*> and store object IDs internally as
C<BIGINT> columns. The referenced objects live in their own tables.

=head3 Object References

    *                   Reference to any Yote object
    *Package::Name      Reference to a specific object class

A bare C<*> allows any object type. A typed reference like
C<*MyApp::User> enforces that only objects of that class (or its
subclasses) may be stored.

    our %cols = (
        owner   => '*MyApp::User',      # must be a User
        misc    => '*',                  # any object
    );

=head3 Arrays

    *ARRAY_<type>       Array (ordered list) of values or references

The C<< <type> >> after C<ARRAY_> specifies what the array holds.
It can be a scalar type, C<*> (any reference), or C<*Package::Name>
(typed reference).

    our %cols = (
        scores   => '*ARRAY_INTEGER',               # array of integers
        tags     => '*ARRAY_VARCHAR(50)',             # array of short strings
        items    => '*ARRAY_*MyApp::Item',            # array of typed objects
        related  => '*ARRAY_*',                       # array of any objects
        grid     => '*ARRAY_*ARRAY_INTEGER',          # nested: array of arrays
    );

Arrays are represented as tied Perl arrayrefs. They support standard
array operations (push, pop, shift, unshift, splice, indexing). Each
array is stored in a separate table keyed by the owning object's ID
and the element index.

=head3 Hashes

    *HASH<N>_<type>     Hash (key-value map) with max key size N

C<N> is the maximum length of hash keys in characters. The C<< <type> >>
after the C<_> specifies what the hash values hold, same as for arrays.

    our %cols = (
        settings  => '*HASH<256>_TEXT',                # string values
        counts    => '*HASH<128>_INTEGER',              # integer values
        children  => '*HASH<256>_*MyApp::Item',         # typed object values
        lookup    => '*HASH<256>_*',                    # any object values
    );

Hashes are represented as tied Perl hashrefs. They support standard
hash operations (assignment, delete, keys, values, exists). Each hash
is stored in a separate table keyed by the owning object's ID and the
hash key.

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
