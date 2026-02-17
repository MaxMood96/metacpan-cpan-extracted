use v5.40;
use Test2::V1 -ipP;
use blib;
use Acme::Parataxis;
use experimental 'class';
$|++;
#
diag 'Testing exception handling in Acme::Parataxis fibers...';
subtest 'Die inside coroutine, catch outside' => sub {
    my $coro = Acme::Parataxis->new(
        code => sub {
            pass 'Inside the sub. Hang on a sec while I die...';
            die 'Death in coro';
        }
    );
    like dies { $coro->call(); }, qr/Death in coro/, 'Caught exception from coroutine';
    ok $coro->is_done, 'Coroutine is marked as done after die';
};
subtest 'eval inside coroutine' => sub {
    my $coro = Acme::Parataxis->new(
        code => sub {
            pass 'Inside the sub. Hang on a sec while I die inside an eval...';
            eval { die 'Inner death' };
            my $err = $@;
            return 'Survived: ' . $err;
        }
    );
    like $coro->call(), qr/Survived: Inner death/, 'Inner eval caught the death';
    ok $coro->is_done, 'Coroutine finished normally';
};
subtest 'try/catch inside coroutine' => sub {
    my $coro = Acme::Parataxis->new(
        code => sub {
            diag 'Inside fiber: About to try/catch inner death...';
            try { die 'Inner death' } catch ($e) {
                return 'Survived: ' . $e;
            }
        }
    );
    like $coro->call(), qr/Survived: Inner death/, 'Inner catch block executed';
    ok $coro->is_done, 'Coroutine finished normally';
};
subtest 'Nested coroutines exceptions' => sub {
    my $coro1 = Acme::Parataxis->new(
        code => sub {
            diag 'Coro1: Spawning Coro2...';
            my $coro2 = Acme::Parataxis->new(
                code => sub {
                    diag 'Coro2: About to die...';
                    die 'Deep death';
                }
            );
            $coro2->call();
            return 'Coro2 survived?';
        }
    );
    like dies { $coro1->call() }, qr/Deep death/, 'Caught deep death in top-level parent';
};
done_testing();
