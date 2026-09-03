use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use POSIX ();

use Data::HashMap::Shared::SS;

# Regression (0.19): the lock-free get() path bounds an arena key offset before
# memcmp (CWE-125), but its sibling exists() called the unguarded compare, so a
# poisoned key_off crashed exists() while get() returned cleanly.  Both lock-free
# readers must now survive a record whose key_off points outside the arena.
#
# The read runs in a forked child so a regression is a failed test, not a dead
# harness.

my $dir = tempdir(CLEANUP => 1);
my $path = "$dir/poisoned.hm";
my $KEY  = 'a-key-well-over-the-inline-limit';

{
    my $m = Data::HashMap::Shared::SS->new($path, 64);
    $m->put($KEY, 'value');
    $m->sync;
}

# Point the live record's key_off outside the arena.
{
    open my $f, '+<:raw', $path or die $!;
    my $d = do { local $/; <$f> };
    my ($nodes_off)  = unpack 'Q', substr($d, 40, 8);
    my ($states_off) = unpack 'Q', substr($d, 48, 8);
    my ($cap)        = unpack 'L', substr($d, 20, 4);
    my ($arena_cap)  = unpack 'Q', substr($d, 72, 8);

    my $slot;
    for my $i (0 .. $cap - 1) {
        $slot = $i, last if unpack('C', substr($d, $states_off + $i, 1)) >= 2;
    }
    ok(defined $slot, 'located the live slot to poison') or BAIL_OUT('no live slot');

    seek $f, $nodes_off + $slot * 16, 0 or die $!;   # ShmNodeSS.key_off is at +0
    print $f pack 'L', $arena_cap + 0x10000000;
    close $f or die $!;
}

for my $op (qw(get exists)) {
    my $pid = fork // die "fork: $!";
    unless ($pid) {
        my $m = Data::HashMap::Shared::SS->new($path, 64);
        $op eq 'get' ? $m->get($KEY) : $m->exists($KEY);
        POSIX::_exit(0);
    }
    waitpid $pid, 0;
    is($? & 127, 0, "lock-free $op() survives a key_off outside the arena")
        or diag sprintf('child died on signal %d', $? & 127);
}

done_testing;
