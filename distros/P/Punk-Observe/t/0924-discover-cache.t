#!perl
# The discover sample cache: the 2000-record sample ran on every GET of four
# screens, and the keys it finds change at the pace of a schema, not a
# request. Cached per (tenant, source, window), fresh while the store's
# generation is unchanged AND the entry is under a minute old.
#
# Both halves of the validity rule get their own mutant: generation-only
# (live appends move no generation, so the entry would live forever) and
# TTL-only (a seal within the minute would go unseen until it expired).
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe::Query ();
use Punk::Plugin::Observe ();

my $P = 'Punk::Plugin::Observe';

# A store that counts its reads and answers a scripted generation.
{
    package Fake::CountingStore;
    sub new { return bless { tenant => 'acme', gen => 'g1', calls => 0 },
                    shift }
    sub records {
        my ($self) = @_;
        $self->{calls}++;
        return [ { attrs => { 'http.route' => '/a',
                              'service.name' => 's' } } ];
    }
    sub generation { return $_[0]{gen} }
    sub can { return 1 }
}

my $store = Fake::CountingStore->new;
my $st    = { limits => {}, opts => {} };

sub build {
    my (%req) = @_;
    my %vars = (from => '0', to => '0');
    $P->can('_discover')->($st, undef, 'logs', \%vars, $store, \%req);
    return \%vars;
}

# --- the cache is used -------------------------------------------------------
{
    my $v1 = build(range => '1h');
    is($store->{calls}, 1, 'the first build samples');
    ok(scalar @{ $v1->{attr_keys} }, '  and finds keys');

    my $v2 = build(range => '1h');
    is($store->{calls}, 1, 'the second build does not sample again');
    is_deeply([ map { $_->{name} } @{ $v2->{attr_keys} } ],
              [ map { $_->{name} } @{ $v1->{attr_keys} } ],
              '  and offers the same keys');
    is($v2->{attrs_sampled}, $v1->{attrs_sampled},
       '  with the same sample size on the page');
}

# --- a different window is a different entry ---------------------------------
{
    build(range => '6h');
    is($store->{calls}, 2, 'a different range samples afresh');
}

# --- a seal refreshes it (kills the TTL-only mutant) -------------------------
{
    $store->{gen} = 'g2';
    build(range => '1h');
    is($store->{calls}, 3,
       'a generation change refreshes inside the minute');
}

# --- an aged entry refreshes (kills the generation-only mutant) --------------
{
    # Age the entry by hand: deterministic, where a sleep is a race.
    $_->{at} -= 61 for values %{ $st->{discover} };
    build(range => '1h');
    is($store->{calls}, 4, 'an entry over a minute old refreshes');
}

# --- an error page never samples ---------------------------------------------
{
    my %vars = (from => '0', to => '0', error => 'that query could not run');
    my $calls = $store->{calls};
    $P->can('_discover')->($st, undef, 'logs', \%vars, $store,
                           { range => '30m' });
    is($store->{calls}, $calls, 'a failed page buys no extra read');
    ok(!$vars{attr_keys} || !@{ $vars{attr_keys} }, '  and offers no keys');
}

done_testing();
