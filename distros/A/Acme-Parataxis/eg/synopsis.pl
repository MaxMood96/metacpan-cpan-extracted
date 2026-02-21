{
    use v5.40;
    use blib;
    use Acme::Parataxis;
    $|++;

    # Basic usage with the integrated scheduler
    Acme::Parataxis::run(
        sub {
            say 'Main fiber started (TID: ' . Acme::Parataxis->tid . ')';

            # Spawn background workers
            my $f1 = Acme::Parataxis->spawn(
                sub {
                    say '  Task 1: Sleeping (non-blocking for others)...';
                    Acme::Parataxis->await_sleep(1000);
                    return 'Coffee is ready!';
                }
            );
            my $f2 = Acme::Parataxis->spawn(
                sub {
                    say '  Task 2: Calculating... (simulated CPU work)';
                    my $sum = 0;
                    for ( 1 .. 100 ) {
                        $sum += $_;
                        Acme::Parataxis->maybe_yield();    # Be a good neighbor
                    }
                    return $sum;
                }
            );

            # Await results without blocking the main OS thread
            say 'Result 1: ' . $f1->await();
            say 'Result 2: ' . $f2->await();
        }
    );
}
