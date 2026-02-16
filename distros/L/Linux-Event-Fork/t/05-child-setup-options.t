use v5.36;
use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

# Test cwd + env overlay + clear_env + umask.
# We run a small perl child that prints:
#   cwd=<...>
#   foo=<...>
#   path=<... or undef>
#   umask=<...>
sub run_child (%spawn) {
  my $loop = Linux::Event->new;

  my $out = '';
  my $exit;

  $loop->fork(
    %spawn,

    on_stdout => sub ($child, $chunk) { $out .= $chunk },
    on_exit   => sub ($child, $ex) { $exit = $ex; $loop->stop },
  );

  $loop->run;

  ok($exit && $exit->exited, 'child exited');
  is($exit->code, 0, 'exit code 0');
  return $out;
}

# 1) env overlay should preserve PATH by default.
{
  my $out = run_child(
    cmd => [
      $^X, '-we',
      q{
        use Cwd qw(getcwd);
        my $cwd = getcwd();
        print "cwd=$cwd
";
        print "foo=" . ($ENV{FOO}//"") . "
";
        print "path=" . (defined $ENV{PATH} ? 1 : 0) . "
";
        my $m = umask();
        umask($m);
        printf "umask=%04o
", $m;
        exit 0;
      },
    ],
    env => { FOO => "BAR" },
  );

  like($out, qr/^foo=BAR$/m, 'FOO overlay applied');
  like($out, qr/^path=1$/m, 'PATH preserved (overlay)');
}

# 2) clear_env should remove PATH unless explicitly set.
{
  my $out = run_child(
    cmd => [
      $^X, '-we',
      q{
        print "foo=" . ($ENV{FOO}//"") . "
";
        print "path=" . (defined $ENV{PATH} ? 1 : 0) . "
";
        exit 0;
      },
    ],
    clear_env => 1,
    env => { FOO => "Z" },
  );

  like($out, qr/^foo=Z$/m, 'FOO set');
  like($out, qr/^path=0$/m, 'PATH cleared');
}

# 3) cwd and umask applied.
{
  require File::Temp;
  my $dir = File::Temp::tempdir(CLEANUP => 1);

  my $out = run_child(
    cmd => [
      $^X, '-we',
      q{
        use Cwd qw(getcwd);
        my $cwd = getcwd();
        print "cwd=$cwd
";
        my $m = umask();
        umask($m);
        printf "umask=%04o
", $m;
        exit 0;
      },
    ],
    cwd => $dir,
    umask => 027,
  );

  like($out, qr/^cwd=\Q$dir\E$/m, 'cwd changed');
  like($out, qr/^umask=0027$/m, 'umask set');
}

done_testing;
