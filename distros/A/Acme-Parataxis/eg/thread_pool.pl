use v5.40;
use blib;
use Acme::Parataxis;
use Time::HiRes qw[time];
$|++;
Acme::Parataxis::run(
    sub {
        say 'Main: Thread pool size is ' . Acme::Parataxis::get_thread_pool_size();
        my @futures;
        for my $id ( 1 .. 3 ) {
            push @futures, Acme::Parataxis->spawn(
                sub {
                    my $sleep_time = int( rand(2000) ) + 500;
                    say "  [Worker $id] FID: " . Acme::Parataxis->fid . " will sleep for ${sleep_time}ms in background";
                    my $start = time();

                    # This yields to main, background thread sleeps, scheduler resumes us
                    Acme::Parataxis->await_sleep($sleep_time);
                    my $elapsed = int( ( time() - $start ) * 1000 );
                    say "  [Worker $id] Woke up after ${elapsed}ms!";
                    return "Done $id";
                }
            );
        }
        say 'Main: All workers spawned. Waiting for completion...';
        my $start_time = time();

        # Wait for all workers to finish via futures
        $_->await for @futures;
        say 'Main: All workers finished!';
        printf 'Total wallclock time: %.2fs (Note how they ran in parallel!)', time() - $start_time;
    }
);
