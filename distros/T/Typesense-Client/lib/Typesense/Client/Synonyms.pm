package Typesense::Client::Synonyms;
$Typesense::Client::Synonyms::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

class Typesense::Client::Synonyms {
    field $client :param;

    method list ($collection) {
        $client->request(GET => "/collections/$collection/synonyms");
    }

    method get ($collection, $id) {
        $client->request(GET => "/collections/$collection/synonyms/$id");
    }

    ## $body: { synonyms => [...] }           multi-way
    ##        { root => 'x', synonyms => [] } one-way: only x -> the others
    method put ($collection, $id, $body) {
        $client->request(PUT => "/collections/$collection/synonyms/$id", json => $body);
    }

    method delete ($collection, $id) {
        $client->request(DELETE => "/collections/$collection/synonyms/$id", ok_404 => 1);
    }
}

1;

__END__

=head1 NAME

Typesense::Client::Synonyms - query synonyms

=head1 SYNOPSIS

    # multi-way: any of these finds the others
    $ts->synonyms->put('products', 'laptop', {
        synonyms => [qw(laptop notebook computer)],
    });

    # one-way: "laptop" also finds "ultrabook", but not the reverse
    $ts->synonyms->put('products', 'laptop-narrow', {
        root     => 'laptop',
        synonyms => [qw(ultrabook netbook)],
    });

=head1 DESCRIPTION

Synonyms belong to a B<collection>, not to the server. A collection built from
scratch starts with none - so a reindex that creates a new collection and moves
an alias onto it must re-push the synonyms, or the site silently loses them.

=head2 One-way versus multi-way

Without C<root>, every term finds every other. With C<root>, only the root
expands: that is what you want when a general term should also reach the
narrower ones - C<laptop> finding C<ultrabook> - without a search for the
narrow term dragging the whole general set into its results.

=head1 METHODS

=head2 list

C<GET /collections/{c}/synonyms>.

=head2 get

C<GET /collections/{c}/synonyms/{id}>.

=head2 put

C<PUT /collections/{c}/synonyms/{id}>. Creates or replaces. C<$body> is
C<< { synonyms => [...] } >> or C<< { root => '...', synonyms => [...] } >>.

=head2 delete

C<DELETE /collections/{c}/synonyms/{id}>. Not an error if it does not exist.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
