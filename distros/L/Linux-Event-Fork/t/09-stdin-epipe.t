use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

# Regression: writing to child stdin after the child exits (pipe closed) must not kill the parent (SIGPIPE),
# and should be handled as EPIPE with clean teardown.
my $loop = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop);

my $timed = 0;
my $exit;

my $child = $forker->spawn(
  tag => "epipe",

  stdin_pipe => 1,
  timeout => 0.02,

  on_timeout => sub ($c) { $timed++ },

  child => sub {
    $SIG{TERM} = sub { exit 0 };
    # read a tiny bit then wait for TERM
    my $buf = '';
    sysread(STDIN, $buf, 1);
    sleep 5;
    exit 0;
  },

  on_exit => sub ($c, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

# Enqueue a large amount of data; most will remain queued when timeout kills the child.
my $payload = "X" x (10 * 1024 * 1024); # 10 MiB
my $off = 0;
my $len = length($payload);
while ($off < $len) {
  my $piece = substr($payload, $off, 131072);
  $child->stdin_write($piece);
  $off += length($piece);
}
$child->close_stdin;

# Safety stop in case something regresses into a hang.
$loop->after(1, sub ($loop) { $loop->stop });

$loop->run;

ok($timed >= 1, 'timeout fired');
ok($exit && $exit->exited, 'child exited');
is($exit->code, 0, 'child exit code 0 (TERM handler)');

pass('parent survived SIGPIPE/EPIPE case');

done_testing;
