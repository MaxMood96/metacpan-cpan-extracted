use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $seen_tag;
my $exit;

$loop->fork(
  tag => "job-123",

  cmd => [ $^X, '-we', 'print "ok\n"; exit 0' ],

  on_stdout => sub ($child, $chunk) {
    $seen_tag = $child->tag;
  },

  on_exit => sub ($child, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

$loop->run;

ok($exit && $exit->exited, 'child exited');
is($exit->code, 0, 'exit code 0');
is($seen_tag, "job-123", 'tag accessor works');

done_testing;
