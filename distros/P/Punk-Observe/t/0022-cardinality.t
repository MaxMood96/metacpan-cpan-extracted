#!perl
# The cardinality cap, and the shared arena it lives in.
#
# This is the limit that has to hold, because cardinality is the failure mode
# that kills observability backends and it always arrives the same way:
# somebody puts a user id in an attribute.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Config;
use Punk::Observe;

my $S = 'Punk::Observe::Segment';

# --- the cap holds ----------------------------------------------------------

{
    my $h = $S->can('shm_new')->('10');
    ok(defined $h, 'a shared arena is created');

    my @ok = map { $S->can('shm_admit')->($h) } 1 .. 10;
    is(scalar(grep { $_ } @ok), 10, 'the first 10 series are admitted');

    my @over = map { $S->can('shm_admit')->($h) } 1 .. 5;
    is(scalar(grep { $_ } @over), 0, 'the next 5 are refused at the cap');

    my $st = $S->can('shm_stats')->($h);
    is("$st->{series}", '10', 'the counter stopped at the cap');
    is("$st->{rejected}", '5', 'and every refusal is counted');
    is("$st->{overflow}", '5', 'attributed to the overflow bucket');

    $S->can('shm_free')->($h);
}

# A cap of zero means unlimited, not "refuse everything". Getting that
# backwards would make an unconfigured install silently store nothing.
{
    my $h = $S->can('shm_new')->('0');
    my @ok = map { $S->can('shm_admit')->($h) } 1 .. 100;
    is(scalar(grep { $_ } @ok), 100, 'a cap of 0 means unlimited');
    my $st = $S->can('shm_stats')->($h);
    is("$st->{rejected}", '0', '  and nothing is refused');
    $S->can('shm_free')->($h);
}

# --- shared ACROSS THE FORK -------------------------------------------------

# The whole point. A region mapped after the fork is PRIVATE per worker: each
# counts its own series, the effective limit becomes N times what was
# configured, and nothing reports a problem - the operator just finds the cap
# did not hold.
SKIP: {
    skip 'fork not available', 4 unless $Config{d_fork};

    my $h = $S->can('shm_new')->('0');   # mapped BEFORE the fork
    skip 'no shared arena', 4 unless defined $h;

    my @pids;
    for my $w (1 .. 4) {
        my $pid = fork();
        skip 'fork failed', 4 unless defined $pid;
        if ($pid == 0) {
            $S->can('shm_admit')->($h) for 1 .. 250;
            require POSIX;
            POSIX::_exit(0);
        }
        push @pids, $pid;
    }
    waitpid $_, 0 for @pids;

    my $st = $S->can('shm_stats')->($h);
    ok($st->{shared}, 'the arena reports itself shared');

    # Four workers, 250 each. If the mapping were private the parent would see
    # ZERO - which is the silent failure this test exists for.
    isnt("$st->{series}", '0',
         'the parent sees the workers\' counts, so the mapping IS shared');
    is("$st->{series}", '1000',
       '  and the total is exact across 4 forked workers, not 1/4 of it');

    # The same run with a cap: the cap must hold across processes, not per
    # process.
    my $c = $S->can('shm_new')->('600');
    my @p2;
    for my $w (1 .. 4) {
        my $pid = fork();
        last unless defined $pid;
        if ($pid == 0) {
            $S->can('shm_admit')->($c) for 1 .. 250;
            require POSIX;
            POSIX::_exit(0);
        }
        push @p2, $pid;
    }
    waitpid $_, 0 for @p2;
    my $st2 = $S->can('shm_stats')->($c);

    # The check-then-increment is racy by design, so the count may overshoot
    # by at most the worker count. What must be true is that it STOPS - not
    # that it stops at exactly 600. A cap is a guard rail, not a ledger.
    cmp_ok(0 + $st2->{series}, '>=', 600, 'the cap holds across processes');
    cmp_ok(0 + $st2->{series}, '<=', 604,
           '  overshooting by at most the worker count, never by 4x');
    $S->can('shm_free')->($c);
    $S->can('shm_free')->($h);
}

# --- an existing series is never evicted ------------------------------------

# Over the cap the NEW series is dropped and the existing ones keep working.
# The tempting alternative - evict something to make room - converts a
# cardinality problem into data loss on whichever series is least recently
# used, which is very likely the one somebody has open right now.
{
    my $h = $S->can('shm_new')->('3');
    $S->can('shm_admit')->($h) for 1 .. 3;
    my $before = $S->can('shm_stats')->($h);

    $S->can('shm_admit')->($h) for 1 .. 10;
    my $after = $S->can('shm_stats')->($h);

    is("$after->{series}", "$before->{series}",
       'the admitted count never DROPS when the cap refuses new series');
    is("$after->{rejected}", '10', '  and every refusal is counted');
    $S->can('shm_free')->($h);
}

done_testing();
