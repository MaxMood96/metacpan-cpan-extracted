use v5.40;
use blib;
use Acme::Parataxis qw[:all];
#
async {
    say 'Main fiber started';

    # 'fiber' is the modern alias for 'spawn'
    my $f1 = fiber {
        say '  Fiber 1: Sleeping...';
        await_sleep(1000);
        say '  Fiber 1: Woke up!';
        return 42;
    };

    # 'await' is the modern way to wait for results
    my $res1 = await $f1;
    say 'Main: Fiber 1 returned ' . $res1;
    say 'Creating a manual fiber for bidirectional communication...';

    # Even if you create it with Acme::Parataxis->new,
    # you can use 'await' if it's running in the scheduler
    my $f2 = Acme::Parataxis->new(
        code => sub {
            say '  Fiber 2: Yielding some data...';
            my $received = yield('Data from F2');
            say '  Fiber 2: Resumed with: ' . $received;
            return 'Final result from F2';
        }
    );

    # The manual call/yield pattern works alongside the scheduler
    my $yielded = $f2->call();
    say 'Main: Fiber 2 yielded: ' . $yielded;
    $f2->call('Data from Main');
    say 'Main: Fiber 2 is ' . ( $f2->is_done ? 'done' : 'still running' );
    say 'All done!';
};
