use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $stderr = '';
my $exit;

$loop->fork(
  capture_stderr => 1,

  child => sub {
    die "boom from child";
  },

  on_stderr => sub ($child, $chunk) {
    $stderr .= $chunk;
  },

  on_exit => sub ($child, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

$loop->run;

ok($exit, 'got exit object');
ok($exit->exited, 'exited');
is($exit->code, 127, 'exit code 127 on child failure');

like($stderr, qr/Linux::Event::Fork child error:/, 'has diagnostic prefix');
like($stderr, qr/boom from child/, 'includes die message');

done_testing;
