use v5.40;
use blib;
use Acme::Parataxis qw[:all];
use Time::HiRes     qw[time];
$|++;

# Demonstrate dynamic thread pool growth and modern API
async {
    say 'Main: Initial thread pool size is ' . Acme::Parataxis::get_thread_pool_size();
    my @futures;
    for my $id ( 1 .. 5 ) {
        push @futures, fiber {
            my $fid        = current_fid();
            my $sleep_time = int( rand(1000) ) + 500;
            say "  [Worker $id] Fiber #$fid will sleep for ${sleep_time}ms in background pool";
            my $start = time();

            # This yields to main, background thread sleeps, scheduler resumes us
            await_sleep($sleep_time);
            my $elapsed = int( ( time() - $start ) * 1000 );
            say "  [Worker $id] Fiber #$fid woke up after ${elapsed}ms!";
            return "Done $id";
        };
    }
    say 'Main: All workers spawned. Waiting for completion...';
    say 'Main: Thread pool size during load: ' . Acme::Parataxis::get_thread_pool_size();
    my $start_time = time();

    # Wait for all workers to finish via futures using modern 'await'
    await $_ for @futures;
    say 'Main: All workers finished!';
    printf "Total wallclock time: %.2fs\n", time() - $start_time;
    say 'Main: Final thread pool size: ' . Acme::Parataxis::get_thread_pool_size();
};
