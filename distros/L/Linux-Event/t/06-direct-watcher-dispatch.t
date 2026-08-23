use v5.36;
use Test::More;
use Linux::Event::Loop;
use POSIX qw(:fcntl_h);

pipe(my $r, my $w) or die "pipe: $!";
fcntl($r, F_SETFL, fcntl($r, F_GETFL, 0) | O_NONBLOCK) or die "fcntl r: $!";
fcntl($w, F_SETFL, fcntl($w, F_GETFL, 0) | O_NONBLOCK) or die "fcntl w: $!";

my $loop = Linux::Event::Loop->new;
my $got = 0;
my $watcher = $loop->watch_fd(fileno($r), fh => $r, read => sub { sysread($r, my $buf, 16); $got++; $loop->stop }, no_args => 1);

syswrite($w, "x");
$loop->run;

is($got, 1, 'read callback fired');
my $stats = $loop->stats;
ok($stats->{direct_watcher_events} >= 1, 'direct watcher pointer dispatch was counted');
is($stats->{watcher_lookup_calls}, 0, 'fd registry lookup not used in dispatch hot path');

done_testing;
