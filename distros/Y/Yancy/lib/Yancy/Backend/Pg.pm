package Yancy::Backend::Pg;
our $VERSION = '1.088';
# ABSTRACT: A backend for Postgres using Mojo::Pg

#pod =head1 SYNOPSIS
#pod
#pod     ### URL string
#pod     use Mojolicious::Lite;
#pod     plugin Yancy => {
#pod         backend => 'pg://user:pass@localhost/mydb',
#pod         read_schema => 1,
#pod     };
#pod
#pod     ### Mojo::Pg object
#pod     use Mojolicious::Lite;
#pod     use Mojo::Pg;
#pod     plugin Yancy => {
#pod         backend => { Pg => Mojo::Pg->new( 'postgres:///myapp' ) },
#pod         read_schema => 1,
#pod     };
#pod
#pod     ### Hashref
#pod     use Mojolicious::Lite;
#pod     plugin Yancy => {
#pod         backend => {
#pod             Pg => {
#pod                 dsn => 'dbi:Pg:dbname',
#pod                 username => 'fry',
#pod                 password => 'b3nd3r1sgr34t',
#pod             },
#pod         },
#pod         read_schema => 1,
#pod     };
#pod
#pod
#pod =head1 DESCRIPTION
#pod
#pod This Yancy backend allows you to connect to a Postgres database to manage
#pod the data inside. This backend uses L<Mojo::Pg> to connect to Postgres.
#pod
#pod See L<Yancy::Backend> for the methods this backend has and their return
#pod values.
#pod
#pod =head2 Backend URL
#pod
#pod The URL for this backend takes the form C<<
#pod pg://<user>:<pass>@<host>:<port>/<db> >>.
#pod
#pod Some examples:
#pod
#pod     # Just a DB
#pod     pg:///mydb
#pod
#pod     # User+DB (server on localhost:5432)
#pod     pg://user@/mydb
#pod
#pod     # User+Pass Host and DB
#pod     pg://user:pass@example.com/mydb
#pod
#pod =head2 Schema Names
#pod
#pod The schema names for this backend are the names of the tables in the
#pod database.
#pod
#pod So, if you have the following schema:
#pod
#pod     CREATE TABLE people (
#pod         id SERIAL,
#pod         name VARCHAR NOT NULL,
#pod         email VARCHAR NOT NULL
#pod     );
#pod     CREATE TABLE business (
#pod         id SERIAL,
#pod         name VARCHAR NOT NULL,
#pod         email VARCHAR NULL
#pod     );
#pod
#pod You could map that to the following schema:
#pod
#pod     {
#pod         backend => 'pg://user@/mydb',
#pod         schema => {
#pod             People => {
#pod                 required => [ 'name', 'email' ],
#pod                 properties => {
#pod                     id => {
#pod                         type => 'integer',
#pod                         readOnly => 1,
#pod                     },
#pod                     name => { type => 'string' },
#pod                     email => { type => 'string' },
#pod                 },
#pod             },
#pod             Business => {
#pod                 required => [ 'name' ],
#pod                 properties => {
#pod                     id => {
#pod                         type => 'integer',
#pod                         readOnly => 1,
#pod                     },
#pod                     name => { type => 'string' },
#pod                     email => { type => 'string' },
#pod                 },
#pod             },
#pod         },
#pod     }
#pod
#pod =head2 Ignored Tables
#pod
#pod By default, this backend will ignore some tables when using
#pod C<read_schema>: Tables used by L<Mojo::Pg::Migrations>,
#pod L<DBIx::Class::Schema::Versioned> (in case we're co-habitating with
#pod a DBIx::Class schema), and all the tables used by the
#pod L<Minion::Backend::Pg> Minion backend.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Mojo::Pg>, L<Yancy>
#pod
#pod =cut

use Mojo::Base 'Yancy::Backend::MojoDB';
use Mojo::JSON qw( encode_json );
use Scalar::Util qw( blessed );
BEGIN {
    eval { require Mojo::Pg; Mojo::Pg->VERSION( 4.03 ); 1 }
        or die "Could not load Pg backend: Mojo::Pg version 4.03 or higher required\n";
}

sub new {
    my ( $class, $driver, $schema ) = @_;
    if ( blessed $driver ) {
        die "Need a Mojo::Pg object. Got " . blessed( $driver )
            if !$driver->isa( 'Mojo::Pg' );
        return $class->SUPER::new( $driver, $schema );
    }
    elsif ( ref $driver eq 'HASH' ) {
        my $pg = Mojo::Pg->new;
        for my $method ( keys %$driver ) {
            $pg->$method( $driver->{ $method } );
        }
        return $class->SUPER::new( $pg, $schema );
    }
    my $found = (my $connect = $driver) =~ s{^.*?:}{};
    return $class->SUPER::new(
        Mojo::Pg->new( $found ? "postgres:$connect" : () ),
        $schema,
    );
}

sub table_info {
    my ( $self ) = @_;
    my $dbh = $self->dbh;
    my $schema = $self->driver->db->query( 'SELECT current_schema()' )->array->[0];
    return $dbh->table_info( undef, $schema, '%', undef )->fetchall_arrayref({});
}

sub fixup_default {
    my ( $self, $value ) = @_;
    return undef if !defined $value or $value =~ /^nextval/i or $value eq 'NULL';
    return "now" if $value =~ /^(?:NOW|(?:CURRENT_|LOCAL|STATEMENT_|TRANSACTION_|CLOCK_)(?:DATE|TIME(?:STAMP)?))(?:\(\))?/i;
    return 0 if $value eq '0.0';
    $self->driver->db->query( 'SELECT ' . $value )->array->[0];
}

sub create {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    my $res = $self->driver->db->insert( $coll, $params, { returning => $id_field } );
    my $row = $res->hash;
    return ref $id_field eq 'ARRAY'
        ? { map { $_ => $row->{$_} } @$id_field }
        : $row->{ $id_field }
        ;
}

sub create_p {
    my ( $self, $coll, $params ) = @_;
    $params = $self->normalize( $coll, $params );
    my $id_field = $self->id_field( $coll );
    return $self->driver->db->insert_p( $coll, $params, { returning => $id_field } )
        ->then( sub {
            my $row = shift->hash;
            return ref $id_field eq 'ARRAY'
                ? { map { $_ => $row->{$_} } @$id_field }
                : $row->{ $id_field }
                ;
        } );
}

sub column_info {
    my ( $self, $table ) = @_;
    my $columns = $self->dbh->column_info( @{$table}{qw( TABLE_CAT TABLE_SCHEM TABLE_NAME )}, '%' )->fetchall_arrayref({});
    for my $c ( @$columns ) {
        if ( $c->{pg_enum_values} ) {
            $c->{ENUM} = $c->{pg_enum_values};
        }
        if ( $c->{COLUMN_DEF} && $c->{COLUMN_DEF} =~ /nextval/i ) {
            $c->{AUTO_INCREMENT} = 1;
        }
        $c->{COLUMN_DEF} = $self->fixup_default( $c->{COLUMN_DEF} );
    }
    return $columns;
}

1;

__END__

=pod

=head1 NAME

Yancy::Backend::Pg - A backend for Postgres using Mojo::Pg

=head1 VERSION

version 1.088

=head1 SYNOPSIS

    ### URL string
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'pg://user:pass@localhost/mydb',
        read_schema => 1,
    };

    ### Mojo::Pg object
    use Mojolicious::Lite;
    use Mojo::Pg;
    plugin Yancy => {
        backend => { Pg => Mojo::Pg->new( 'postgres:///myapp' ) },
        read_schema => 1,
    };

    ### Hashref
    use Mojolicious::Lite;
    plugin Yancy => {
        backend => {
            Pg => {
                dsn => 'dbi:Pg:dbname',
                username => 'fry',
                password => 'b3nd3r1sgr34t',
            },
        },
        read_schema => 1,
    };

=head1 DESCRIPTION

This Yancy backend allows you to connect to a Postgres database to manage
the data inside. This backend uses L<Mojo::Pg> to connect to Postgres.

See L<Yancy::Backend> for the methods this backend has and their return
values.

=head2 Backend URL

The URL for this backend takes the form C<<
pg://<user>:<pass>@<host>:<port>/<db> >>.

Some examples:

    # Just a DB
    pg:///mydb

    # User+DB (server on localhost:5432)
    pg://user@/mydb

    # User+Pass Host and DB
    pg://user:pass@example.com/mydb

=head2 Schema Names

The schema names for this backend are the names of the tables in the
database.

So, if you have the following schema:

    CREATE TABLE people (
        id SERIAL,
        name VARCHAR NOT NULL,
        email VARCHAR NOT NULL
    );
    CREATE TABLE business (
        id SERIAL,
        name VARCHAR NOT NULL,
        email VARCHAR NULL
    );

You could map that to the following schema:

    {
        backend => 'pg://user@/mydb',
        schema => {
            People => {
                required => [ 'name', 'email' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
            Business => {
                required => [ 'name' ],
                properties => {
                    id => {
                        type => 'integer',
                        readOnly => 1,
                    },
                    name => { type => 'string' },
                    email => { type => 'string' },
                },
            },
        },
    }

=head2 Ignored Tables

By default, this backend will ignore some tables when using
C<read_schema>: Tables used by L<Mojo::Pg::Migrations>,
L<DBIx::Class::Schema::Versioned> (in case we're co-habitating with
a DBIx::Class schema), and all the tables used by the
L<Minion::Backend::Pg> Minion backend.

=head1 SEE ALSO

L<Mojo::Pg>, L<Yancy>

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
