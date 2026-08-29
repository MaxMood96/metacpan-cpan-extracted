package Typesense::Client::Aliases;
$Typesense::Client::Aliases::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

class Typesense::Client::Aliases {
    field $client :param;

    method list { $client->request(GET => '/aliases') }

    method get ($alias) { $client->request(GET => "/aliases/$alias") }

    method set ($alias, $collection) {
        $client->request(PUT => "/aliases/$alias", json => { collection_name => $collection });
    }

    method delete ($alias) { $client->request(DELETE => "/aliases/$alias", ok_404 => 1) }
}

1;

__END__

=head1 NAME

Typesense::Client::Aliases - collection aliases, for reindexing without downtime

=head1 SYNOPSIS

    # Build the new index under a fresh, timestamped name...
    my $new = 'products_' . $stamp;
    $ts->collections->create({ name => $new, fields => [...] });
    $ts->documents->import_docs($new, \@docs);

    # ...check it before anyone searches it...
    die 'short index' if $ts->collections->get($new)->{num_documents} < $expected;

    # ...and swap in one atomic call.
    $ts->aliases->set('products', $new);
    $ts->collections->drop($old);

=head1 DESCRIPTION

An alias is a name that points at a collection. Searching the alias searches
whatever it currently points to, so pointing it somewhere else swaps an entire
index atomically, with no window where the site has no results.

This is the reason to always search an alias and never a collection directly.

=head1 METHODS

=head2 list

C<GET /aliases>.

=head2 get

C<GET /aliases/{alias}>. Returns the alias and its C<collection_name>.

=head2 set

C<PUT /aliases/{alias}>. Creates or repoints. Atomic.

=head2 delete

C<DELETE /aliases/{alias}>. An alias that does not exist is not an error.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
