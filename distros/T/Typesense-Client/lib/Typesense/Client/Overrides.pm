package Typesense::Client::Overrides;
$Typesense::Client::Overrides::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

class Typesense::Client::Overrides {
    field $client :param;

    method list ($collection) {
        $client->request(GET => "/collections/$collection/overrides");
    }

    method get ($collection, $id) {
        $client->request(GET => "/collections/$collection/overrides/$id");
    }

    method put ($collection, $id, $body) {
        $client->request(PUT => "/collections/$collection/overrides/$id", json => $body);
    }

    method delete ($collection, $id) {
        $client->request(DELETE => "/collections/$collection/overrides/$id", ok_404 => 1);
    }
}

1;

__END__

=head1 NAME

Typesense::Client::Overrides - curation: pinning and hiding results

=head1 SYNOPSIS

    # For "black friday", put document 1024 first and hide 512.
    $ts->overrides->put('products', 'bf-promo', {
        rule            => { query => 'black friday', match => 'exact' },
        includes        => [ { id => '1024', position => 1 } ],
        excludes        => [ { id => '512' } ],
        effective_from_ts => 1793491200,
        effective_to_ts   => 1793923200,
    });

=head1 DESCRIPTION

An override is a merchandising rule: for a given query, force certain documents
to certain positions, or remove them. It applies on top of the ranking, so the
rest of the results keep their normal order.

The window fields C<effective_from_ts> and C<effective_to_ts> make a campaign
expire on its own, which is what you want for anything seasonal - nobody has to
remember to take it down.

=head1 METHODS

=head2 list

C<GET /collections/{c}/overrides>.

=head2 get

C<GET /collections/{c}/overrides/{id}>.

=head2 put

C<PUT /collections/{c}/overrides/{id}>. Creates or replaces. The body holds
C<rule> (with C<query> and C<match>, or C<filter_by>), plus C<includes>,
C<excludes>, C<filter_by>, C<sort_by>, C<replace_query> and the two
C<effective_*_ts> fields.

=head2 delete

C<DELETE /collections/{c}/overrides/{id}>. Not an error if absent.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
