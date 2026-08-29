#!/usr/bin/env perl
# Reindex a collection with no downtime: build a fresh one, verify it, and
# only then move the alias. This is the pattern that keeps a live site from
# ever serving an empty index.

use v5.38;
use warnings;
use Typesense::Client;

my $ts = Typesense::Client->new(
    url     => $ENV{TYPESENSE_URL} // 'http://localhost:8108',
    api_key => $ENV{TYPESENSE_API_KEY} // die "set TYPESENSE_API_KEY\n",
);

my $alias = 'products';
my @stamp = localtime;
my $new   = sprintf '%s_%04d%02d%02d%02d%02d%02d', $alias,
            $stamp[5] + 1900, $stamp[4] + 1, @stamp[3, 2, 1, 0];

say "building $new";
$ts->collections->create({
    name   => $new,
    fields => [
        { name => 'name',       type => 'string'            },
        { name => 'brand',      type => 'string', facet => \1 },  # JSON boolean
        { name => 'popularity', type => 'int32'             },
    ],
    default_sorting_field => 'popularity',
});

my @docs = map {
    {
        id         => "$_",
        name       => "Product $_",
        brand      => 'ACME',
        popularity => $_,
    }
} 1 .. 5_000;

my $r = $ts->documents->import_docs($new, \@docs);
say "indexed $r->{ok}/$r->{total}";

## An HTTP 200 does not mean every document was indexed:
## inspect the per-document import result.
if ($r->{failed}) {
    warn "$r->{failed} rejected, first: $r->{errors}[0]\n";
    $ts->collections->drop($new);
    die "aborting, alias untouched\n";
}

## Verify what the server actually sees before sending traffic to it.
my $indexed = $ts->collections->get($new)->{num_documents};
if ($indexed < @docs * 0.99) {
    $ts->collections->drop($new);
    die "short index ($indexed of ${\ scalar @docs}), alias untouched\n";
}

my $old = eval { $ts->aliases->get($alias)->{collection_name} };
$ts->aliases->set($alias, $new);
say "alias $alias -> $new";

## Synonyms belong to the collection, not the server. A newly created
## collection starts without them, so they must be restored explicitly.
$ts->synonyms->put($new, 'common-terms', {
    synonyms => [qw(laptop notebook computer)]
});

## Keep the previous collection around: rollback is just another alias swap.
say "previous collection kept for rollback: $old"
    if $old && $old ne $new;
