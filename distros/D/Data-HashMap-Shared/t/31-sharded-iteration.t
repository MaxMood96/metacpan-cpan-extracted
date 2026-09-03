use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Data::HashMap::Shared::SI;

# Regression (0.19): the dispatcher's shard_iter served two masters -- each()'s
# shard-progress cursor and pop/shift/drain's round-robin start.  Draining a
# sharded map during an each() moved the cursor past shards the iteration had
# not visited, so each() silently skipped live keys.  pop/shift/drain now use a
# separate shard_rr.  The invariant: a key each() never yields must be a key
# that is no longer there.

my $dir = tempdir(CLEANUP => 1);
my @keys = map { "sharded-iter-key-longer-than-inline-$_" } 1 .. 40;

for my $case (
    [ 'pop',   sub { $_[0]->pop } ],
    [ 'shift', sub { $_[0]->shift } ],
    [ 'drain', sub { $_[0]->drain(2) } ],
) {
    my ($name, $act) = @$case;
    my $m = Data::HashMap::Shared::SI->new_sharded("$dir/$name", 4, 1000);
    $m->put($_, 1) for @keys;
    is($m->size, scalar @keys, "$name: seeded all keys");

    my (%seen, $step);
    while (my ($k, $v) = $m->each) {
        $seen{$k} = 1;
        $act->($m) if ++$step == 5;         # drain mid-iteration
    }

    my @skipped_but_live = grep { !$seen{$_} && $m->exists($_) } @keys;
    is(scalar @skipped_but_live, 0,
       "$name during each(): no live key is skipped by the iteration")
        or diag "skipped while still live: @skipped_but_live";
}

# Regression (0.19): clear() reset each shard but not the dispatcher's own
# shard cursor, so an each() left part-way through before the clear resumed at
# that shard afterwards and never visited the ones below it.
{
    my $m = Data::HashMap::Shared::SI->new_sharded("$dir/cleared", 4, 1000);
    $m->put($_, 1) for @keys;

    my $n = 0;
    while (my ($k, $v) = $m->each) { last if ++$n >= 15 }   # abandon mid-iteration
    $m->clear;

    my @after = map { "post-clear-$_" } @keys;
    $m->put($_, 1) for @after;

    my %seen;
    while (my ($k, $v) = $m->each) { $seen{$k} = 1 }
    is scalar(keys %seen), scalar @after,
        'each() after clear() visits every shard, not just the ones above the old cursor';
}

done_testing;
