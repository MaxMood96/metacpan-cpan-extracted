use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $out = '';
my $exit;

$loop->fork(
  child => sub {
    # no shell; exec list
    exec $^X, '-we', 'print "cb-ok\n"; exit 9';
  },

  on_stdout => sub ($child, $chunk) { $out .= $chunk },

  on_exit => sub ($child, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

$loop->run;

is($out, "cb-ok\n", 'stdout captured from child callback exec');
ok($exit, 'got exit');
ok($exit->exited, 'exited');
is($exit->code, 9, 'exit code');

done_testing;
