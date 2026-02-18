{
    use v5.40;
    use blib;
    use Acme::Parataxis;
    $|++;

    # Basic usage with the integrated scheduler
    Acme::Parataxis::run(
        sub {
            say 'Main task started';

            # Spawn background workers
            my $f1 = Acme::Parataxis->spawn(
                sub {
                    say '  Task 1: Sleeping in a native thread pool...';
                    Acme::Parataxis->await_sleep(1000);
                    say '  Task 1: Ah! What a nice nap...';
                    return 42;
                }
            );
            my $f2 = Acme::Parataxis->spawn(
                sub {
                    say '  Task 2: Performing I/O...';

                    # await_read/write for non-blocking socket handling
                    return 'I/O Done';
                }
            );

            # Block current fiber until results are ready (without blocking the thread)
            say 'Result 1: ' . $f1->await();
            say 'Result 2: ' . $f2->await();
        }
    );
}
