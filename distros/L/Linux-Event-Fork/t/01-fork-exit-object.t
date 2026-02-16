use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $got_out = '';
my $got_err = '';
my $got_exit;

$loop->fork(
  cmd => [
    $^X, '-we',
    q{
      print STDOUT "ok-out\n";
      print STDERR "ok-err\n";
      exit 7;
    },
  ],

  on_stdout => sub ($child, $chunk) { $got_out .= $chunk },
  on_stderr => sub ($child, $chunk) { $got_err .= $chunk },

  on_exit => sub ($child, $exit) {
    $got_exit = $exit;
    $loop->stop;
  },
);

$loop->run;

like($got_out, qr/^ok-out\n\z/);
like($got_err, qr/^ok-err\n\z/);

ok($got_exit, 'got exit object');
isa_ok($got_exit, 'Linux::Event::Fork::Exit');

ok($got_exit->exited, 'exited');
is($got_exit->code, 7, 'exit code');
is($got_exit->signaled, 0, 'not signaled');

done_testing;
