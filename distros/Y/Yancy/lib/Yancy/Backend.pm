package Yancy::Backend;
our $VERSION = '1.088';
# ABSTRACT: Interface to a database

#pod =head1 SYNOPSIS
#pod
#pod     my $be = Yancy::Backend->new( $url );
#pod
#pod     $result = $be->list( $schema, $where, $options );
#pod     say "Total: " . $result->{total};
#pod     say "Name: " . $_->{name} for @{ $result->{items} };
#pod
#pod     $item = $be->get( $schema, $id );
#pod     $be->set( $schema, $id, $item );
#pod     $be->delete( $schema, $id );
#pod     $id = $be->create( $schema, $item );
#pod
#pod =head1 DESCRIPTION
#pod
#pod A C<Yancy::Backend> handles talking to the database. Different Yancy
#pod backends will support different databases. To use a backend, see
#pod L</SUPPORTED BACKENDS>. To make your own backend, see L</METHODS> for
#pod the list of methods each backend supports, their arguments, and their
#pod return values.
#pod
#pod =head2 Terminology
#pod
#pod Yancy backends work with schemas, which are made up of items.
#pod A schema is a set of items, like a database table. An item is
#pod a single element of a schema, and must be a hashref.
#pod
#pod =head2 Asynchronous Backends
#pod
#pod Asynchronous backends implement both a synchronous and an asynchronous
#pod API (using promises).
#pod
#pod =head2 Synchronous-only Backends
#pod
#pod Synchronous-only backends also implement a promises API for
#pod compatibility, but will not perform requests concurrently.
#pod
#pod =head1 SUPPORTED BACKENDS
#pod
#pod =over
#pod
#pod =item * L<Yancy::Backend::Pg> - Postgres backend
#pod
#pod =item * L<Yancy::Backend::Mysql> - MySQL backend
#pod
#pod =item * L<Yancy::Backend::Sqlite> - SQLite backend
#pod
#pod =item * L<Yancy::Backend::Dbic> - L<DBIx::Class> backend
#pod
#pod =back
#pod
#pod Other backends are available on CPAN.
#pod
#pod =over
#pod
#pod =item * L<Yancy::Backend::Static> - Backend for a static site generator
#pod with Markdown.
#pod
#pod =back
#pod
#pod =head1 EXTENDING
#pod
#pod To create your own Yancy::Backend for a new database system, inherit
#pod from this class and provide the standard six interface methods: L</get>,
#pod L</create>, L</set>, L</list>, L</delete>, and L</read_schema>.
#pod
#pod There are roles to aid backend development:
#pod
#pod =over
#pod
#pod =item * L<Yancy::Backend::Role::DBI> provides some methods based on
#pod L<DBI>
#pod
#pod =item * L<Yancy::Backend::Role::Sync> provides promise-based API methods
#pod for databases which are synchronous-only.
#pod
#pod =back
#pod
#pod Backends do not have to talk to databases. For an example, see
#pod L<Yancy::Backend::Static> for a backend that uses plain files like
#pod a static site generator.
#pod
#pod =cut

use Mojo::Base '-base';
use Scalar::Util qw( blessed );
use Yancy::Util qw( is_type is_format );
use Mojo::JSON qw( encode_json );

has schema => sub { {} };
sub collections {
    require Carp;
    Carp::carp( '"collections" method is now "schema"' );
    shift->schema( @_ );
}

#pod =head1 METHODS
#pod
#pod =head2 new
#pod
#pod     my $url = 'memory://custom_string';
#pod     my $be = Yancy::Backend::Memory->new( $url, $schema );
#pod
#pod Create a new backend object. C<$url> is a string that begins with the
#pod backend name followed by a colon. Everything else in the URL is for the
#pod backend to use to describe how to connect to the underlying database and
#pod any options for the backend object itself.
#pod
#pod The backend name will be run through C<ucfirst> before being looked up
#pod in C<Yancy::Backend::>. For example, C<mysql://...> will use the
#pod L<Yancy::Backend::Mysql> module.
#pod
#pod C<$schema> is a hash reference of schema configuration from the Yancy
#pod configuration. See L<Yancy::Guides::Schema> for more information.
#pod
#pod =cut

sub new {
    my ( $class, $driver, $schema ) = @_;
    if ( $class eq __PACKAGE__ ) {
        return load_backend( $driver, $schema );
    }
    return $class->SUPER::new( driver => $driver, schema => $schema // {} );
}

#pod =head2 list
#pod
#pod     my $result = $be->list( $schema, $where, %opt );
#pod     # { total => ..., items => [ ... ] }
#pod
#pod Fetch a list of items from a schema. C<$schema> is the
#pod schema name.
#pod
#pod C<$where> is a L<SQL::Abstract where structure|SQL::Abstract/WHERE
#pod CLAUSES>.
#pod
#pod     # Search for all Dougs
#pod     $be->list( 'people', { name => { -like => 'Doug%' } } );
#pod     # Find adults
#pod     $be->list( 'people', { age => { '>=' => 18 } } );
#pod     # Find men we can contact
#pod     $be->list( 'people', { gender => 'male', contact => 1 } );
#pod
#pod Additionally, Yancy backends support the following additional
#pod keys in the where structure:
#pod
#pod =over
#pod
#pod =item -has (EXPERIMENTAL)
#pod
#pod The C<-has> operator searches inside a data structure (an array or
#pod a hash). This operator examines the type of the field being searched to
#pod perform the appropriate query.
#pod
#pod     # Create a new page with an array of tags and a hash of author
#pod     # information
#pod     $be->create( pages => {
#pod         title => 'Release v1.481',
#pod         tags => [ 'release', 'minor' ],
#pod         author => {
#pod             name => 'Doug Bell',
#pod             email => 'doug@example.com',
#pod         },
#pod     } );
#pod
#pod     # All pages that have the tag "release"
#pod     $be->list( pages => { tags => { -has => 'release' } } );
#pod
#pod     # All pages that have both the tags "release" and "major"
#pod     $be->list( pages => { tags => { -has => [ 'release', 'major' ] } } );
#pod
#pod     # All pages that have the author's name starting with Doug
#pod     $be->list( pages => { author => { -has => { name => { -like => 'Doug%' } } } } );
#pod
#pod This is not yet supported by all backends, and may never be supported by
#pod some. Postgres has array columns and JSON fields. MySQL has JSON fields.
#pod The L<Yancy::Util/match> function matches against Perl data structures.
#pod All of these should support C<-has> and C<-not_has> before it can be
#pod considered not experimental.
#pod
#pod =back
#pod
#pod C<%opt> is a list of name/value pairs with the following keys:
#pod
#pod =over
#pod
#pod =item * limit - The number of items to return
#pod
#pod =item * offset - The number of items to skip
#pod
#pod =item * order_by - A L<SQL::Abstract order by clause|SQL::Abstract/ORDER BY CLAUSES>
#pod
#pod =item * join - Join one or more tables using a C<x-foreign-key> field.
#pod This can be the name of a foreign key field on this schema, or the name
#pod of a table with a foreign key field that refers to this schema. Join
#pod multiple tables at the same time by passing an arrayref of joins. Fields
#pod in joined tables can be queried by prefixing the join name to the field,
#pod separated by a dot.
#pod
#pod =back
#pod
#pod     # Get the second page of 20 people
#pod     $be->list( 'people', {}, limit => 20, offset => 20 );
#pod     # Get the list of people sorted by age, oldest first
#pod     $be->list( 'people', {}, order_by => { -desc => 'age' } );
#pod     # Get the list of people sorted by age first, then name (ascending)
#pod     $be->list( 'people', {}, order_by => [ 'age', 'name' ] );
#pod
#pod Returns a hashref with two keys:
#pod
#pod =over
#pod
#pod =item items
#pod
#pod An array reference of hash references of item data
#pod
#pod =item total
#pod
#pod The total count of items that would be returned without C<limit> or
#pod C<offset>.
#pod
#pod =back
#pod
#pod =cut

sub list { ... }

#pod =head2 list_p
#pod
#pod     my $promise = $be->list_p( $schema, $where, %opt );
#pod     $promise->then( sub {
#pod         my ( $result ) = @_;
#pod         # { total => ..., items => [ ... ] }
#pod     } );
#pod
#pod Fetch a list of items asynchronously using promises. Returns a promise that
#pod resolves to a hashref with C<items> and C<total> keys. See L</list> for
#pod arguments and return values.
#pod
#pod =cut

sub list_p { ... }

#pod =head2 get
#pod
#pod     my $item = $be->get( $schema, $id, %opts );
#pod
#pod Get a single item. C<$schema> is the schema name. C<$id> is the
#pod ID of the item to get: Either a string for a single key field, or a
#pod hash reference for a composite key. Returns a hashref of item data.
#pod
#pod C<%opts> is a list of name/value pairs of options with the following
#pod names:
#pod
#pod =over
#pod
#pod =item join
#pod
#pod Join one or more tables using a C<x-foreign-key> field. This should be
#pod the name of the schema to join, either by a foreign key on this table,
#pod or a foreign key on the joined table. Join multiple tables at the same
#pod time by passing an arrayref of joins.
#pod
#pod =cut

sub get { ... }

#pod =head2 get_p
#pod
#pod     my $promise = $be->get_p( $schema, $id );
#pod     $promise->then( sub {
#pod         my ( $item ) = @_;
#pod         # ...
#pod     } );
#pod
#pod Get a single item asynchronously using promises. Returns a promise that
#pod resolves to the item. See L</get> for arguments and return values.
#pod
#pod =cut

sub get_p { ... }

#pod =head2 set
#pod
#pod     my $success = $be->set( $schema, $id, $item );
#pod
#pod Update an item. C<$schema> is the schema name. C<$id> is the ID of the
#pod item to update: Either a string for a single key field, or a hash
#pod reference for a composite key. C<$item> is the item's data to set.
#pod Returns a boolean that is true if a row with the given ID was found and
#pod updated, false otherwise.
#pod
#pod Currently the values of the data cannot be references, only simple
#pod scalars or JSON booleans.
#pod
#pod =cut

sub set { ... }

#pod =head2 set_p
#pod
#pod     my $promise = $be->set_p( $schema, $id );
#pod     $promise->then( sub {
#pod         my ( $success ) = @_;
#pod         # ...
#pod     } );
#pod
#pod Update a single item asynchronously using promises. Returns a promise
#pod that resolves to a boolean indicating if the row was updated. See
#pod L</set> for arguments and return values.
#pod
#pod =cut

sub set_p { ... }

#pod =head2 create
#pod
#pod     my $id = $be->create( $schema, $item );
#pod
#pod Create a new item. C<$schema> is the schema name.  C<$item> is
#pod the item's data. Returns the ID of the row created suitable to be passed
#pod in to C<the get() method|/get>.
#pod
#pod Currently the values of the data cannot be references, only simple
#pod scalars or JSON booleans.
#pod
#pod =cut

sub create { ... }

#pod =head2 create_p
#pod
#pod     my $promise = $be->create_p( $schema, $item );
#pod     $promise->then( sub {
#pod         my ( $id ) = @_;
#pod         # ...
#pod     } );
#pod
#pod Create a new item asynchronously using promises. Returns a promise that
#pod resolves to the ID of the newly-created item. See L</create> for
#pod arguments and return values.
#pod
#pod =cut

sub create_p { ... }

#pod =head2 delete
#pod
#pod     $be->delete( $schema, $id );
#pod
#pod Delete an item. C<$schema> is the schema name. C<$id> is the ID of the
#pod item to delete: Either a string for a single key field, or a hash
#pod reference for a composite key. Returns a boolean that is true if a row
#pod with the given ID was found and deleted. False otherwise.
#pod
#pod =cut

sub delete { ... }

#pod =head2 delete_p
#pod
#pod     my $promise = $be->delete_p( $schema, $id );
#pod     $promise->then( sub {
#pod         my ( $success ) = @_;
#pod         # ...
#pod     } );
#pod
#pod Delete an item asynchronously using promises. Returns a promise that
#pod resolves to a boolean indicating if the row was deleted. See L</delete>
#pod for arguments and return values.
#pod
#pod =cut

sub delete_p { ... }

#pod =head2 query
#pod
#pod Run a raw query on the backend. Each backend may have its own arguments.
#pod Returns a list of hash references of data.
#pod
#pod =cut

sub query { ... }

#pod =head2 query_p
#pod
#pod Run a raw query on the backend. Each backend may have its own arguments.
#pod Returns a promise that resolves into a list of hash references of data.
#pod
#pod =cut

sub query_p { ... }

#pod =head2 read_schema
#pod
#pod     my $schema = $be->read_schema;
#pod     my $table = $be->read_schema( $table_name );
#pod
#pod Read the schema from the database tables. Returns an OpenAPI schema
#pod ready to be merged into the user's configuration. Can be restricted
#pod to only a single table.
#pod
#pod =cut

sub read_schema { ... }

#pod =head1 INTERNAL METHODS
#pod
#pod These methods are documented for use in subclasses and should not need
#pod to be called externally.
#pod
#pod =head2 supports
#pod
#pod Returns true if the backend supports a given feature. Returns false for now.
#pod In the future, features like 'json' will be detectable.
#pod
#pod =cut

sub supports { 0 }

#pod =head2 ignore_table
#pod
#pod Returns true if the given table should be ignored when doing L</read_schema>.
#pod By default, backends will ignore tables used by:
#pod
#pod =over
#pod
#pod =item * L<Minion> backends (L<Minion::Backend::mysql>, L<Minion::Backend::Pg>, L<Minion::Backend::SQLite>)
#pod =item * L<DBIx::Class::Schema::Versioned>
#pod =item * Mojo DB migrations (L<Mojo::mysql::Migrations>, L<Mojo::Pg::Migrations>, L<Mojo::SQLite::Migrations>)
#pod =item * L<Mojo::mysql::PubSub>
#pod
#pod =back
#pod
#pod =cut

our %IGNORE_TABLE = (
    mojo_migrations => 1,
    minion_jobs => 1,
    minion_workers => 1,
    minion_locks => 1,
    minion_workers_inbox => 1,
    minion_jobs_depends => 1,
    mojo_pubsub_subscribe => 1,
    mojo_pubsub_notify => 1,
    dbix_class_schema_versions => 1,
);
sub ignore_table {
    return $IGNORE_TABLE{ $_[1] } // 0;
}

#pod =head2 normalize
#pod
#pod This method normalizes data to and from the database.
#pod
#pod =cut

sub normalize {
    my ( $self, $schema_name, $data ) = @_;
    return undef if !$data;
    my $schema = $self->schema->{ $schema_name };
    my $real_schema_name = ( $schema->{'x-view'} || {} )->{schema} // $schema_name;
    my %props = %{
        $schema->{properties} || $self->schema->{ $real_schema_name }{properties}
    };
    my %replace;
    for my $key ( keys %$data ) {
        next if !defined $data->{ $key }; # leave nulls alone
        my $prop = $props{ $key } || next;
        my ( $type, $format ) = @{ $prop }{qw( type format )};
        if ( is_type( $type, 'boolean' ) ) {
            # Boolean: true (1, "true"), false (0, "false")
            $replace{ $key }
                = $data->{ $key } && $data->{ $key } !~ /^false$/i
                ? 1 : 0;
        }
        elsif ( is_type( $type, 'string' ) && is_format( $format, 'date-time' ) ) {
            if ( !$data->{ $key } ) {
                $replace{ $key } = undef;
            }
            elsif ( $data->{ $key } eq 'now' ) {
                $replace{ $key } = \'CURRENT_TIMESTAMP';
            }
            else {
                $replace{ $key } = $data->{ $key };
                $replace{ $key } =~ s/T/ /;
            }
        }
    }

    my $params = +{ %$data, %replace };
    return $params;
}

#pod =head2 id_field
#pod
#pod Get the ID field for the given schema. Defaults to C<id>.
#pod =cut

sub id_field {
    my ( $self, $schema ) = @_;
    return $self->schema->{ $schema }{ 'x-id-field' } || 'id';
}

#pod =head2 id_where
#pod
#pod Get the query structure for the ID field of the given schema with the
#pod given ID value.
#pod
#pod =cut

sub id_where {
    my ( $self, $schema_name, $id ) = @_;
    my %where;
    my $id_field = $self->id_field( $schema_name );
    if ( ref $id_field eq 'ARRAY' ) {
        for my $field ( @$id_field ) {
            next unless exists $id->{ $field };
            $where{ $field } = $id->{ $field };
        }
        die "Missing composite ID parts" if @$id_field > keys %where;
    }
    else {
        $where{ $id_field } = $id;
    }
    return %where;
}

1;

__END__

=pod

=head1 NAME

Yancy::Backend - Interface to a database

=head1 VERSION

version 1.088

=head1 SYNOPSIS

    my $be = Yancy::Backend->new( $url );

    $result = $be->list( $schema, $where, $options );
    say "Total: " . $result->{total};
    say "Name: " . $_->{name} for @{ $result->{items} };

    $item = $be->get( $schema, $id );
    $be->set( $schema, $id, $item );
    $be->delete( $schema, $id );
    $id = $be->create( $schema, $item );

=head1 DESCRIPTION

A C<Yancy::Backend> handles talking to the database. Different Yancy
backends will support different databases. To use a backend, see
L</SUPPORTED BACKENDS>. To make your own backend, see L</METHODS> for
the list of methods each backend supports, their arguments, and their
return values.

=head2 Terminology

Yancy backends work with schemas, which are made up of items.
A schema is a set of items, like a database table. An item is
a single element of a schema, and must be a hashref.

=head2 Asynchronous Backends

Asynchronous backends implement both a synchronous and an asynchronous
API (using promises).

=head2 Synchronous-only Backends

Synchronous-only backends also implement a promises API for
compatibility, but will not perform requests concurrently.

=head1 SUPPORTED BACKENDS

=over

=item * L<Yancy::Backend::Pg> - Postgres backend

=item * L<Yancy::Backend::Mysql> - MySQL backend

=item * L<Yancy::Backend::Sqlite> - SQLite backend

=item * L<Yancy::Backend::Dbic> - L<DBIx::Class> backend

=back

Other backends are available on CPAN.

=over

=item * L<Yancy::Backend::Static> - Backend for a static site generator
with Markdown.

=back

=head1 EXTENDING

To create your own Yancy::Backend for a new database system, inherit
from this class and provide the standard six interface methods: L</get>,
L</create>, L</set>, L</list>, L</delete>, and L</read_schema>.

There are roles to aid backend development:

=over

=item * L<Yancy::Backend::Role::DBI> provides some methods based on
L<DBI>

=item * L<Yancy::Backend::Role::Sync> provides promise-based API methods
for databases which are synchronous-only.

=back

Backends do not have to talk to databases. For an example, see
L<Yancy::Backend::Static> for a backend that uses plain files like
a static site generator.

=head1 METHODS

=head2 new

    my $url = 'memory://custom_string';
    my $be = Yancy::Backend::Memory->new( $url, $schema );

Create a new backend object. C<$url> is a string that begins with the
backend name followed by a colon. Everything else in the URL is for the
backend to use to describe how to connect to the underlying database and
any options for the backend object itself.

The backend name will be run through C<ucfirst> before being looked up
in C<Yancy::Backend::>. For example, C<mysql://...> will use the
L<Yancy::Backend::Mysql> module.

C<$schema> is a hash reference of schema configuration from the Yancy
configuration. See L<Yancy::Guides::Schema> for more information.

=head2 list

    my $result = $be->list( $schema, $where, %opt );
    # { total => ..., items => [ ... ] }

Fetch a list of items from a schema. C<$schema> is the
schema name.

C<$where> is a L<SQL::Abstract where structure|SQL::Abstract/WHERE
CLAUSES>.

    # Search for all Dougs
    $be->list( 'people', { name => { -like => 'Doug%' } } );
    # Find adults
    $be->list( 'people', { age => { '>=' => 18 } } );
    # Find men we can contact
    $be->list( 'people', { gender => 'male', contact => 1 } );

Additionally, Yancy backends support the following additional
keys in the where structure:

=over

=item -has (EXPERIMENTAL)

The C<-has> operator searches inside a data structure (an array or
a hash). This operator examines the type of the field being searched to
perform the appropriate query.

    # Create a new page with an array of tags and a hash of author
    # information
    $be->create( pages => {
        title => 'Release v1.481',
        tags => [ 'release', 'minor' ],
        author => {
            name => 'Doug Bell',
            email => 'doug@example.com',
        },
    } );

    # All pages that have the tag "release"
    $be->list( pages => { tags => { -has => 'release' } } );

    # All pages that have both the tags "release" and "major"
    $be->list( pages => { tags => { -has => [ 'release', 'major' ] } } );

    # All pages that have the author's name starting with Doug
    $be->list( pages => { author => { -has => { name => { -like => 'Doug%' } } } } );

This is not yet supported by all backends, and may never be supported by
some. Postgres has array columns and JSON fields. MySQL has JSON fields.
The L<Yancy::Util/match> function matches against Perl data structures.
All of these should support C<-has> and C<-not_has> before it can be
considered not experimental.

=back

C<%opt> is a list of name/value pairs with the following keys:

=over

=item * limit - The number of items to return

=item * offset - The number of items to skip

=item * order_by - A L<SQL::Abstract order by clause|SQL::Abstract/ORDER BY CLAUSES>

=item * join - Join one or more tables using a C<x-foreign-key> field.
This can be the name of a foreign key field on this schema, or the name
of a table with a foreign key field that refers to this schema. Join
multiple tables at the same time by passing an arrayref of joins. Fields
in joined tables can be queried by prefixing the join name to the field,
separated by a dot.

=back

    # Get the second page of 20 people
    $be->list( 'people', {}, limit => 20, offset => 20 );
    # Get the list of people sorted by age, oldest first
    $be->list( 'people', {}, order_by => { -desc => 'age' } );
    # Get the list of people sorted by age first, then name (ascending)
    $be->list( 'people', {}, order_by => [ 'age', 'name' ] );

Returns a hashref with two keys:

=over

=item items

An array reference of hash references of item data

=item total

The total count of items that would be returned without C<limit> or
C<offset>.

=back

=head2 list_p

    my $promise = $be->list_p( $schema, $where, %opt );
    $promise->then( sub {
        my ( $result ) = @_;
        # { total => ..., items => [ ... ] }
    } );

Fetch a list of items asynchronously using promises. Returns a promise that
resolves to a hashref with C<items> and C<total> keys. See L</list> for
arguments and return values.

=head2 get

    my $item = $be->get( $schema, $id, %opts );

Get a single item. C<$schema> is the schema name. C<$id> is the
ID of the item to get: Either a string for a single key field, or a
hash reference for a composite key. Returns a hashref of item data.

C<%opts> is a list of name/value pairs of options with the following
names:

=over

=item join

Join one or more tables using a C<x-foreign-key> field. This should be
the name of the schema to join, either by a foreign key on this table,
or a foreign key on the joined table. Join multiple tables at the same
time by passing an arrayref of joins.

=head2 get_p

    my $promise = $be->get_p( $schema, $id );
    $promise->then( sub {
        my ( $item ) = @_;
        # ...
    } );

Get a single item asynchronously using promises. Returns a promise that
resolves to the item. See L</get> for arguments and return values.

=head2 set

    my $success = $be->set( $schema, $id, $item );

Update an item. C<$schema> is the schema name. C<$id> is the ID of the
item to update: Either a string for a single key field, or a hash
reference for a composite key. C<$item> is the item's data to set.
Returns a boolean that is true if a row with the given ID was found and
updated, false otherwise.

Currently the values of the data cannot be references, only simple
scalars or JSON booleans.

=head2 set_p

    my $promise = $be->set_p( $schema, $id );
    $promise->then( sub {
        my ( $success ) = @_;
        # ...
    } );

Update a single item asynchronously using promises. Returns a promise
that resolves to a boolean indicating if the row was updated. See
L</set> for arguments and return values.

=head2 create

    my $id = $be->create( $schema, $item );

Create a new item. C<$schema> is the schema name.  C<$item> is
the item's data. Returns the ID of the row created suitable to be passed
in to C<the get() method|/get>.

Currently the values of the data cannot be references, only simple
scalars or JSON booleans.

=head2 create_p

    my $promise = $be->create_p( $schema, $item );
    $promise->then( sub {
        my ( $id ) = @_;
        # ...
    } );

Create a new item asynchronously using promises. Returns a promise that
resolves to the ID of the newly-created item. See L</create> for
arguments and return values.

=head2 delete

    $be->delete( $schema, $id );

Delete an item. C<$schema> is the schema name. C<$id> is the ID of the
item to delete: Either a string for a single key field, or a hash
reference for a composite key. Returns a boolean that is true if a row
with the given ID was found and deleted. False otherwise.

=head2 delete_p

    my $promise = $be->delete_p( $schema, $id );
    $promise->then( sub {
        my ( $success ) = @_;
        # ...
    } );

Delete an item asynchronously using promises. Returns a promise that
resolves to a boolean indicating if the row was deleted. See L</delete>
for arguments and return values.

=head2 query

Run a raw query on the backend. Each backend may have its own arguments.
Returns a list of hash references of data.

=head2 query_p

Run a raw query on the backend. Each backend may have its own arguments.
Returns a promise that resolves into a list of hash references of data.

=head2 read_schema

    my $schema = $be->read_schema;
    my $table = $be->read_schema( $table_name );

Read the schema from the database tables. Returns an OpenAPI schema
ready to be merged into the user's configuration. Can be restricted
to only a single table.

=head1 INTERNAL METHODS

These methods are documented for use in subclasses and should not need
to be called externally.

=head2 supports

Returns true if the backend supports a given feature. Returns false for now.
In the future, features like 'json' will be detectable.

=head2 ignore_table

Returns true if the given table should be ignored when doing L</read_schema>.
By default, backends will ignore tables used by:

=over

=item * L<Minion> backends (L<Minion::Backend::mysql>, L<Minion::Backend::Pg>, L<Minion::Backend::SQLite>)
=item * L<DBIx::Class::Schema::Versioned>
=item * Mojo DB migrations (L<Mojo::mysql::Migrations>, L<Mojo::Pg::Migrations>, L<Mojo::SQLite::Migrations>)
=item * L<Mojo::mysql::PubSub>

=back

=head2 normalize

This method normalizes data to and from the database.

=head2 id_field

Get the ID field for the given schema. Defaults to C<id>.

=head2 id_where

Get the query structure for the ID field of the given schema with the
given ID value.

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
