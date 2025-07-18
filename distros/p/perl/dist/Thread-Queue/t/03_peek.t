use strict;
use warnings;

use Config;
BEGIN {
    if (! $Config{'useithreads'}) {
        print("1..0 # SKIP Perl not compiled with 'useithreads'\n");
        exit(0);
    }
}

use threads;
use Thread::Queue;
use Test::More 'tests' => 19;

my $q = Thread::Queue->new(1..10);
ok($q, 'New queue');

$q->enqueue([ qw/foo bar/ ]);

sub q_check
{
    is($q->peek(3), 4, 'Peek at queue');
    is($q->peek(-3), 9, 'Negative peek');

    my $nada = $q->peek(20);
    ok(! defined($nada), 'Big peek');
    $nada = $q->peek(-20);
    ok(! defined($nada), 'Big negative peek');

    my $ary = $q->peek(-1);
    is_deeply($ary, [ qw/foo bar/ ], 'Peek array');

    is($q->pending(), 11, 'Queue count in thread');
}

threads->create(sub {
    q_check();
    threads->create('q_check')->join();
})->join();
q_check();

exit(0);

# EOF
