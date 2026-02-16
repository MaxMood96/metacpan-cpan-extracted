use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $out = '';
my $exit;

my $payload = "X" x (1024 * 1024);  # 1 MiB

my $child = $loop->fork(
  stdin_pipe => 1,

  child => sub {
    my $buf = '';
    my $n = 0;
    while (1) {
      my $r = sysread(STDIN, $buf, 65536);
      last if !defined $r || $r == 0;
      $n += $r;
    }
    print "read=$n\n";
    exit 0;
  },

  on_stdout => sub ($c, $chunk) { $out .= $chunk },

  on_exit => sub ($c, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

my $sent = 0;
while ($sent < length($payload)) {
  my $piece = substr($payload, $sent, 131072); # 128 KiB
  $child->stdin_write($piece);
  $sent += length($piece);
}

$child->close_stdin;

$loop->run;

ok($exit && $exit->exited, 'child exited');
is($exit->code, 0, 'exit code 0');

like($out, qr/^read=\Q@{[length($payload)]}\E\n\z/, 'child read full payload');

done_testing;
