use v5.40;
use blib;
$|++;
use Acme::Parataxis;
Acme::Parataxis::run(
    sub {
        say 'Main coroutine started on OS thread ' . Acme::Parataxis->tid;
        my $f1 = Acme::Parataxis->spawn(
            sub {
                say '  C1 started, sleeping...';
                Acme::Parataxis->await_sleep(500);
                my $cpu = Acme::Parataxis->await_core_id;
                say '  C1 resumed on CPU ' . ( $cpu // 'UNDEFINED' );
                return 'C1 Success';
            }
        );
        my $f2 = Acme::Parataxis->spawn(
            sub {
                say '  C2 started, sleeping...';
                Acme::Parataxis->await_sleep(200);
                my $cpu = Acme::Parataxis->await_core_id;
                say '  C2 resumed on CPU ' . ( $cpu // 'UNDEFINED' );
                return 'C2 Success';
            }
        );
        say 'Waiting for C1: ' . $f1->await();
        say 'Waiting for C2: ' . $f2->await();
        say 'All done!';
    }
);
