package Typesense::Client::Analytics;
$Typesense::Client::Analytics::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

class Typesense::Client::Analytics {
    field $client :param;

    ## ---- rules -----------------------------------------------------------

    method rules { $client->request(GET => '/analytics/rules') }

    method rule ($name) { $client->request(GET => "/analytics/rules/$name") }

    method upsert_rule ($name, $body) {
        $client->request(PUT => "/analytics/rules/$name", json => $body);
    }

    method delete_rule ($name) {
        $client->request(DELETE => "/analytics/rules/$name", ok_404 => 1);
    }

    ## ---- events ----------------------------------------------------------

    ## $data carries doc_id and, optionally, user_id (the same identifier sent
    ## with the search as x-typesense-user-id: without it Typesense aggregates
    ## by IP, and behind a proxy that is one single person). The search side of
    ## that pairing is Typesense::Client::search with headers => {...}.
    method event ($type, $name, $data) {
        $client->request(POST => '/analytics/events',
                         json => { type => $type, name => $name, data => $data });
    }

    method click      ($name, $data) { $self->event(click      => $name, $data) }
    method conversion ($name, $data) { $self->event(conversion => $name, $data) }
    method visit      ($name, $data) { $self->event(visit      => $name, $data) }

    ## ---- sugar -----------------------------------------------------------

    ## Aggregated queries land in an ordinary collection, so they are read by
    ## searching it: q=* sorted by descending counter.
    method top_queries ($destination, %opt) {
        $client->search($destination, {
            q        => '*',
            query_by => 'q',
            sort_by  => 'count:desc',
            per_page => $opt{limit} // 50,
            ($opt{page} ? (page => $opt{page}) : ()),
        });
    }
}

1;

__END__

=head1 NAME

Typesense::Client::Analytics - popular queries, no-hits queries and click events

=head1 SYNOPSIS

    my $a = $ts->analytics;

    # Aggregate what people search for into its own collection.
    $a->upsert_rule('popular_products', {
        type   => 'popular_queries',
        params => {
            source      => { collections => ['products'] },
            destination => { collection  => 'product_queries' },
            limit       => 1000,
            expand_query => \1,           # store the full term, not the prefix
        },
    });

    # And what they search for and do not find.
    $a->upsert_rule('nohits_products', {
        type   => 'nohits_queries',
        params => {
            source      => { collections => ['products'] },
            destination => { collection  => 'product_nohits' },
            limit       => 1000,
        },
    });

    # Feed real popularity back into ranking.
    $a->upsert_rule('product_popularity', {
        type   => 'counter',
        params => {
            source => { collections => ['products'],
                        events => [ { type => 'click', weight => 1,
                                      name => 'product_click' } ] },
            destination => { collection => 'products', counter_field => 'popularity' },
        },
    });

    ## The other half of the pairing: the same id on the search itself.
    $ts->search('products', { q => 'laptop', query_by => 'name' },
                headers => { 'x-typesense-user-id' => $session_id });

    $a->click('product_click', { doc_id => '1024', user_id => $session_id });

    my $top = $a->top_queries('product_queries', limit => 20);

=head1 DESCRIPTION

Typesense can aggregate search traffic on its own. That matters most for a
type-ahead, where logging every keystroke server-side is both expensive and
useless: Typesense only counts a query after a B<four-second pause>, so what
lands in the destination collection is what the person actually finished
typing, not the prefixes on the way there.

=head2 The server has to be started for it

None of this works unless the server runs with:

    --enable-search-analytics=true
    --analytics-dir=/data/analytics
    --analytics-flush-interval=300      # seconds; the default is 3600

Without those flags rules can be created and will simply never produce
anything, which is a confusing way to fail. Check C<< $ts->debug >> or the
server log if a destination collection stays empty.

=head2 Reading the results

There is no endpoint that returns aggregated analytics. The rules write into
ordinary collections, which you search like any other - that is all
L</top_queries> does.

=head2 Attributing events to people

Pass the same identifier as C<user_id> on events and as the
C<x-typesense-user-id> header (or C<X-TYPESENSE-USER-ID> parameter) on
searches. Without it Typesense falls back to the client IP, and behind a
reverse proxy that makes every visitor look like one very busy person.

=head1 METHODS

=head2 rules

C<GET /analytics/rules>.

=head2 rule

C<GET /analytics/rules/{name}>.

=head2 upsert_rule

C<PUT /analytics/rules/{name}>. C<type> is C<popular_queries>,
C<nohits_queries> or C<counter>.

=head2 delete_rule

C<DELETE /analytics/rules/{name}>. Not an error if absent.

=head2 event

    $a->event($type, $name, \%data);

C<POST /analytics/events>. C<$name> must match the event name declared in a
C<counter> rule for it to be counted.

=head2 click, conversion, visit

Shorthands for the three event types.

=head2 top_queries

    my $r = $a->top_queries($destination_collection, limit => 20);

Searches a C<popular_queries> or C<nohits_queries> destination collection,
ordered by count. Convenience only - it is a plain search.

=head1 SEE ALSO

L<Typesense::Client>

L<https://typesense.org/docs/latest/api/analytics-query-suggestions.html>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
