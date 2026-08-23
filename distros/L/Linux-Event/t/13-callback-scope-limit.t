use v5.36;
use Test::More;
use Linux::Event::Loop;
use IO::Handle;

my $loop = Linux::Event::Loop->new;
is($loop->callback_scope_limit, 128, 'default is 128 callbacks per scope');

$loop->set_callback_scope_limit(4);
is($loop->callback_scope_limit, 4, 'callback scope limit is configurable for tuning');

my @reads;
my @writes;
my @watchers;
my $called = 0;

for my $i (1 .. 20) {
    pipe(my $r, my $w) or die $!;
    $r->blocking(0);
    $w->blocking(0);
    push @reads, $r;
    push @writes, $w;

    my $watcher;
    $watcher = $loop->watch_fd(
        fileno($r),
        fh => $r,
        no_args => 1,
        lean => 1,
        read => sub {
            sysread($r, my $buf, 1);
            $called++;
            $watcher->cancel;
        },
    );
    push @watchers, $watcher;
    syswrite($w, 'x');
}

$loop->run_once(1000);
is($called, 20, 'all ready callbacks executed');

my $stats = $loop->stats;
is($stats->{callback_scope_limit}, 4, 'stats report configured scope limit');
ok($stats->{callback_scope_rotations} >= 4, 'bounded scope rotated during a large ready batch');
ok($stats->{callback_batch_scope_enters} >= 5, 'multiple Perl scopes were entered');
ok($stats->{callback_scope_max_callbacks} <= 4, 'no Perl scope exceeded configured callback limit');

$loop->set_callback_scope_limit(0);
is($loop->callback_scope_limit, 0, 'zero selects whole-batch callback scope behavior');

close $_ for @writes;
close $_ for @reads;

done_testing;
