use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

# 1) capture_stderr => 1 without on_stderr should still drain and complete.
{
  my $loop = Linux::Event->new;

  my $exit;
  my $out = '';

  $loop->fork(
    cmd => [
      $^X, '-we',
      q{
        print STDERR ("E" x 20000);
        print STDOUT "ok
";
        exit 0;
      },
    ],

    capture_stderr => 1,   # drain even without on_stderr
    on_stdout => sub ($child, $chunk) { $out .= $chunk },

    on_exit => sub ($child, $ex) {
      $exit = $ex;
      $loop->stop;
    },
  );

  $loop->run;

  ok($exit, 'got exit');
  ok($exit->exited, 'exited');
  is($exit->code, 0, 'exit code 0');
  is($out, "ok
", 'stdout captured');
}

# 2) capture_stdout => 0 should disable capture even if on_stdout is provided.
{
  my $loop = Linux::Event->new;

  my $exit;
  my $called = 0;

  $loop->fork(
    cmd => [
      $^X, '-we',
      q{ print STDOUT "SHOULD_NOT_BE_CAPTURED
"; exit 0; },
    ],

    capture_stdout => 0,
    on_stdout => sub ($child, $chunk) { $called++ },

    on_exit => sub ($child, $ex) {
      $exit = $ex;
      $loop->stop;
    },
  );

  $loop->run;

  ok($exit && $exit->exited, 'got exit');
  is($exit->code, 0, 'exit code 0');
  is($called, 0, 'on_stdout not called when capture_stdout is 0');
}

done_testing;
