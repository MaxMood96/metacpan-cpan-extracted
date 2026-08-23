use v5.36;
use Test::More;
use Linux::Event::Loop;

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my $seen = 0;
my $watcher;
$watcher = $loop->watch_fd(
    fileno($r),
    fh => $r,
    no_args => 1,
    lean => 1,
    read => sub {
        sysread($r, my $buf, 16);
        $seen++;
        $watcher->cancel;
    },
);

ok($watcher->lean, 'watcher is marked lean');
is($watcher->fh, undef, 'lean watcher does not retain fh accessor ref');
is($watcher->loop, undef, 'lean watcher does not retain loop accessor ref');

syswrite($w, "x");
$loop->run_once(100);
is($seen, 1, 'lean no-arg callback fired');

my $st = $loop->stats;
is($st->{lean_watchers}, 1, 'lean watcher stat counted');
is($st->{callback_noarg_calls}, 1, 'no-arg callback counted');

close $r;
close $w;
done_testing;
