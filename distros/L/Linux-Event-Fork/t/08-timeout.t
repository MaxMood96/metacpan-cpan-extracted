use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

# 1) Timeout fires and sends TERM.
{
  my $loop = Linux::Event->new;

  my $timed = 0;
  my $exit;

  $loop->fork(
    timeout => 0.05,
    on_timeout => sub ($child) { $timed++ },

    child => sub {
      $SIG{TERM} = sub { exit 0 };
      sleep 5;
      exit 0;
    },

    on_exit => sub ($child, $ex) {
      $exit = $ex;
      $loop->stop;
    },
  );

  $loop->run;

  ok($timed >= 1, 'on_timeout fired');
  ok($exit && $exit->exited, 'child exited');
  is($exit->code, 0, 'child exited after TERM handler');
}

# 2) Timeout does not fire for fast child.
{
  my $loop = Linux::Event->new;

  my $timed = 0;
  my $exit;

  $loop->fork(
    timeout => 1,
    on_timeout => sub ($child) { $timed++ },

    cmd => [ $^X, '-we', 'exit 0' ],

    on_exit => sub ($child, $ex) {
      $exit = $ex;
      $loop->stop;
    },
  );

  $loop->run;

  is($timed, 0, 'no timeout for fast child');
  ok($exit && $exit->exited, 'child exited');
  is($exit->code, 0, 'exit 0');
}

done_testing;
