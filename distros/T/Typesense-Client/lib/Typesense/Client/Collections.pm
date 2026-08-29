package Typesense::Client::Collections;
$Typesense::Client::Collections::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

class Typesense::Client::Collections {
    field $client :param;

    method list { $client->request(GET => '/collections') }

    method create ($schema) { $client->request(POST => '/collections', json => $schema) }

    method get ($name) { $client->request(GET => "/collections/$name") }

    ## PATCH only accepts adding or dropping fields; the rest of the schema is
    ## immutable in Typesense. Changing a type means reindexing into a new
    ## collection and moving the alias (see Typesense::Client::Aliases).
    method update ($name, $changes) {
        $client->request(PATCH => "/collections/$name", json => $changes);
    }

    method drop ($name) { $client->request(DELETE => "/collections/$name", ok_404 => 1) }
}

1;

__END__

=head1 NAME

Typesense::Client::Collections - collection management

=head1 SYNOPSIS

    my $c = $ts->collections;

    $c->create({
        name   => 'products',
        fields => [ { name => 'name', type => 'string' } ],
    });

    my $all  = $c->list;
    my $one  = $c->get('products');
    $c->update('products', { fields => [ { name => 'stock', type => 'int32' } ] });
    $c->drop('products');

=head1 METHODS

=head2 list

C<GET /collections>. Every collection on the server.

=head2 create

C<POST /collections>. Takes the schema as a hash reference.

=head2 get

C<GET /collections/{name}>. Includes C<num_documents>, which is what you check
after a bulk import.

=head2 update

C<PATCH /collections/{name}>. Typesense only allows B<adding and dropping
fields> here; the rest of the schema is immutable. Changing a field's type
means indexing into a new collection and moving an alias - see
L<Typesense::Client::Aliases>.

=head2 drop

C<DELETE /collections/{name}>. A collection that is already gone is not an
error: the call returns C<undef> rather than throwing.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
