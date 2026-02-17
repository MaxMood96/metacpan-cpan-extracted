use v5.40;
use Test2::V1 -ipP;
use blib;
use Acme::Parataxis;
use Time::HiRes qw[time];
$|++;
Acme::Parataxis::run(
    sub {
        my $start_time = time();
        diag "Starting parallel sleeps at $start_time...";
        my @futures;
        for my $i ( 1 .. 3 ) {
            push @futures, Acme::Parataxis->spawn(
                sub {
                    my $id = $i;    # Closure capture
                    diag "Fiber $id started (FID: " . Acme::Parataxis->fid . ')';
                    diag "Fiber $id: Sleeping for 1000ms...";
                    Acme::Parataxis->await_sleep(1000);
                    diag "Fiber $id: Woke up!";
                    return $id;
                }
            );
        }

        # Wait for all
        diag 'Main: Waiting for 3 fibers to finish...';
        my @results;
        push @results, $_->await() for @futures;
        my $elapsed = time() - $start_time;
        diag "Total wallclock time: $elapsed seconds";
        diag 'Results: ' . join( ', ', @results );
        is \@results, [ 1, 2, 3 ], 'Fibers returned correct individual results';

        # 3 sequential 1-second sleeps would take ~3s
        # 3 parallel 1-second sleeps should take ~1s (plus overhead)
        ok $elapsed < 1.8, 'Three 1-second sleeps ran in parallel (elapsed < 1.8s)';

        # Another test: verify core counts
        my $pool_size = Acme::Parataxis::get_thread_pool_size();
        diag 'Background thread pool size: ' . $pool_size;
        ok $pool_size > 0, 'Thread pool has active workers';
    }
);
done_testing();
