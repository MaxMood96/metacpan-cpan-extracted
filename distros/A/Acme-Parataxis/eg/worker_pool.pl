#!/usr/bin/env perl
use v5.40;
use lib 'lib';
use blib;
use Acme::Parataxis;
use Time::HiRes qw[time];
$|++;

# This simulates a pool of workers processing a queue of jobs.
# Each job 'blocks' by sleeping in the native thread pool (simulating I/O),
# allowing other fibers to continue running concurrently on the main thread.
# I haven't really made good use for any of this because it doesn't work everywhere yet...
Acme::Parataxis::run(
    sub {
        my @jobs = (
            { id => 1, task => 'Fetch User Data',  delay => 800 },
            { id => 2, task => 'Process Payment',  delay => 1200 },
            { id => 3, task => 'Send Email',       delay => 500 },
            { id => 4, task => 'Update Inventory', delay => 1500 },
            { id => 5, task => 'Generate Report',  delay => 900 },
            { id => 6, task => 'Sync Analytics',   delay => 1100 },
        );
        say 'Main: Starting worker pool with 3 fibers...';
        my $start_time = time;

        # Simple shared queue
        my @queue = @jobs;
        my @results;

        # Spawn 3 worker fibers
        my @workers;
        for my $w_id ( 1 .. 3 ) {
            push @workers, Acme::Parataxis->spawn(
                sub {
                    say "  [Worker $w_id] Fiber started.";
                    while ( my $job = shift @queue ) {
                        say "  [Worker $w_id] Processing Job $job->{id}: $job->{task}...";

                        # Simulate a blocking I/O call (DB query, API request, idk...)
                        # This yields to the scheduler while the native thread pool sleeps.
                        Acme::Parataxis->await_sleep( $job->{delay} );
                        say "  [Worker $w_id] Finished Job $job->{id}.";
                        push @results, "Job $job->{id} complete";
                    }
                    return "Worker $w_id finished.";
                }
            );
        }

        # Wait for all workers to complete
        say 'Main: Waiting for pool to drain...';
        $_->await for @workers;
        my $elapsed    = time() - $start_time;
        my $sum_delays = 0;
        $sum_delays += $_->{delay} for @jobs;
        say 'Main: All tasks finished!';
        say 'Total Results: ' . scalar(@results);
        say sprintf 'Total Wallclock Time: %.2fs',     $elapsed;
        say sprintf 'Sum of individual delays: %.2fs', $sum_delays / 1000;
        say sprintf 'Speedup: ~%.2fx', ( $sum_delays / 1000 ) / $elapsed;
    }
);
