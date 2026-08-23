use v5.36;
use Test::More;
use Linux::Event::Loop;

pipe(my $r, my $w) or die $!;
$_->blocking(0) for ($r, $w);

my $loop = Linux::Event::Loop->new;
my $fired = 0;
my $cb = sub { $fired++ };
my $watcher = $loop->watch_fd(
    fileno($r), fh => $r, no_args => 1, read => $cb,
);

syswrite($w, "x");
$loop->run_once(100);

is($fired, 1, 'coderef callback fired');
my $stats = $loop->stats;
is($stats->{callback_direct_cv_calls}, 1, 'direct CV callback path counted');
is($stats->{callback_sv_calls}, 0, 'generic SV callback path not used for plain coderef');

done_testing;
