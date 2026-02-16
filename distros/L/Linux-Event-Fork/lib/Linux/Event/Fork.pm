package Linux::Event::Fork;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.003';

use Carp qw(croak);
use POSIX ();
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

use Linux::Event::Fork::Child ();

sub import ($class, @args) {
  no strict 'refs';
  no warnings 'redefine';

  *{"Linux::Event::Loop::fork"} = sub ($loop, %spawn) {
    my $helper = $loop->{_linux_event_fork} //= $class->new(loop => $loop);
    return $helper->spawn(%spawn);
  };

  return;
}

sub new ($class, %args) {
  my $loop = delete $args{loop};
  croak "loop is required" if !$loop;
  croak "unknown args: " . join(", ", sort keys %args) if %args;

  return bless { loop => $loop }, $class;
}

sub loop ($self) { return $self->{loop} }

sub spawn ($self, %spec) {
  my $cmd   = delete $spec{cmd};
  my $child = delete $spec{child};

  if (defined $cmd && defined $child) {
    croak "provide exactly one of cmd or child";
  }
  if (!defined $cmd && !defined $child) {
    croak "cmd or child is required";
  }

  if (defined $cmd) {
    croak "cmd must be an arrayref" if ref($cmd) ne 'ARRAY' || !@$cmd;
  } else {
    croak "child must be a coderef" if ref($child) ne 'CODE';
  }

  my $on_stdout  = delete $spec{on_stdout};
  my $on_stderr  = delete $spec{on_stderr};
  my $on_exit    = delete $spec{on_exit};
  my $on_timeout = delete $spec{on_timeout};
  my $timeout    = delete $spec{timeout};

  my $tag  = delete $spec{tag};
  my $data = delete $spec{data};

  croak "on_stdout must be a coderef"  if defined($on_stdout)  && ref($on_stdout)  ne 'CODE';
  croak "on_stderr must be a coderef"  if defined($on_stderr)  && ref($on_stderr)  ne 'CODE';
  croak "on_exit must be a coderef"    if defined($on_exit)    && ref($on_exit)    ne 'CODE';
  croak "on_timeout must be a coderef" if defined($on_timeout) && ref($on_timeout) ne 'CODE';
  croak "timeout must be numeric seconds" if defined($timeout) && ref($timeout);

  my $capture_stdout = delete $spec{capture_stdout};
  my $capture_stderr = delete $spec{capture_stderr};

  my $stdin      = delete $spec{stdin};
  my $stdin_pipe = delete $spec{stdin_pipe};
  $stdin_pipe = $stdin_pipe ? 1 : 0 if defined $stdin_pipe;

  my $cwd       = delete $spec{cwd};
  my $umask     = delete $spec{umask};
  my $env       = delete $spec{env};
  my $clear_env = delete $spec{clear_env};

  croak "cwd must be a string" if defined($cwd) && ref($cwd);
  croak "umask must be an integer" if defined($umask) && ref($umask);
  croak "env must be a hashref" if defined($env) && ref($env) ne 'HASH';
  $clear_env = $clear_env ? 1 : 0 if defined $clear_env;

  croak "unknown args: " . join(", ", sort keys %spec) if %spec;

  $capture_stdout = defined($capture_stdout) ? ($capture_stdout ? 1 : 0) : (defined($on_stdout) ? 1 : 0);
  $capture_stderr = defined($capture_stderr) ? ($capture_stderr ? 1 : 0) : (defined($on_stderr) ? 1 : 0);

  my ($out_r, $out_w);
  my ($err_r, $err_w);
  my ($in_r,  $in_w);

  if ($capture_stdout) {
    pipe($out_r, $out_w) or croak "pipe(stdout): $!";
    _set_nonblock($out_r);
  }
  if ($capture_stderr) {
    pipe($err_r, $err_w) or croak "pipe(stderr): $!";
    _set_nonblock($err_r);
  }

  my $want_stdin = (defined($stdin) || $stdin_pipe) ? 1 : 0;
  if ($want_stdin) {
    pipe($in_r, $in_w) or croak "pipe(stdin): $!";
    _set_nonblock($in_w);
  }

  my $pid = fork();
  croak "fork: $!" if !defined $pid;

  if ($pid == 0) {
    my $ok = eval {
      if ($want_stdin) {
        close($in_w);
        POSIX::dup2(fileno($in_r), fileno(*STDIN)) or die "dup2(stdin): $!";
      }
      if ($capture_stdout) {
        close($out_r);
        POSIX::dup2(fileno($out_w), fileno(*STDOUT)) or die "dup2(stdout): $!";
      }
      if ($capture_stderr) {
        close($err_r);
        POSIX::dup2(fileno($err_w), fileno(*STDERR)) or die "dup2(stderr): $!";
      }

      close($in_r)  if $want_stdin;
      close($out_w) if $capture_stdout;
      close($err_w) if $capture_stderr;

      if (defined $umask) {
        umask($umask) or die "umask($umask): $!";
      }
      if (defined $cwd) {
        chdir($cwd) or die "chdir($cwd): $!";
      }

      if ($clear_env) { %ENV = () }
      if (defined $env) { %ENV = (%ENV, %$env) }

      if (defined $cmd) {
        exec { $cmd->[0] } @$cmd;
        die "exec($cmd->[0]): $!";
      } else {
        $child->();
        die "child callback returned";
      }
    };

    if (!$ok) {
      my $err = $@;
      if (defined $err && $err ne '') {
        $err =~ s/\s+\z/\n/;
        syswrite(*STDERR, "Linux::Event::Fork child error: $err");
      }
    }

    POSIX::_exit(127);
  }

  close($out_w) if $capture_stdout;
  close($err_w) if $capture_stderr;
  close($in_r)  if $want_stdin;

  my $handle = Linux::Event::Fork::Child->_new(
    loop => $self->{loop},
    pid  => $pid,

    tag  => $tag,
    data => $data,

    out_r => $out_r,
    err_r => $err_r,
    in_w  => $in_w,

    on_stdout => $on_stdout,
    on_stderr => $on_stderr,
    on_exit   => $on_exit,

    timeout_s  => $timeout,
    on_timeout => $on_timeout,

    capture_stdout => $capture_stdout,
    capture_stderr => $capture_stderr,
  );

  if (defined $stdin && $stdin ne '') {
    $handle->stdin_write($stdin);
  }
  if (defined $stdin && !$stdin_pipe) {
    $handle->close_stdin;
  }

  $handle->_arm;
  return $handle;
}

sub _set_nonblock ($fh) {
  my $flags = fcntl($fh, F_GETFL, 0);
  croak "fcntl(F_GETFL): $!" if !defined $flags;
  my $ok = fcntl($fh, F_SETFL, $flags | O_NONBLOCK);
  croak "fcntl(F_SETFL,O_NONBLOCK): $!" if !$ok;
  return;
}

1;

__END__

=head1 NAME

Linux::Event::Fork - Minimal async child spawning on top of Linux::Event

=head1 SYNOPSIS

  use v5.36;
  use Linux::Event;
  use Linux::Event::Fork;   # installs $loop->fork

  my $loop = Linux::Event->new;

  $loop->fork(
    tag => "job:42",

    cmd => [ $^X, '-we', 'print "hello\n"; exit 0' ],

    on_stdout => sub ($child, $chunk) {
      print "[stdout] $chunk";
    },

    on_exit => sub ($child, $exit) {
      say "pid=" . $child->pid . " code=" . ($exit->exited ? $exit->code : 'n/a');
      $loop->stop;
    },
  );

  $loop->run;

=head1 DESCRIPTION

B<Linux::Event::Fork> is a small policy-layer helper built on top of
L<Linux::Event>. It installs an opt-in method C<< $loop->fork(...) >> into
C<Linux::Event::Loop>.

It uses only public primitives:

=over 4

=item * C<< $loop->watch(...) >> for pipes

=item * C<< $loop->pid(...) >> for exit observation

=item * C<< $loop->after(...) >> for timeouts

=back

=head2 Constraints

=over 4

=item * No restarts/backoff.

=item * No hidden ownership of user resources.

=item * Explicit, idempotent teardown.

=item * Drain-first: C<on_exit> fires only after exit is observed and captured pipes reach EOF.

=back

=head1 SPAWN ARGUMENTS

Exactly one of C<cmd> or C<child> is required.

=head2 cmd

  cmd => [ $program, @argv ]

Uses C<exec>. If exec fails, the child exits 127 and writes a short diagnostic to STDERR.

=head2 child

  child => sub { ... }

Runs a Perl callback in the child after stdio plumbing and setup options are applied.
Typically you call C<exec> from inside the callback.

If the callback throws an exception or returns normally, the child exits 127 and writes
a best-effort diagnostic to STDERR.

=head2 Output capture

  on_stdout => sub ($child, $chunk) { ... }
  on_stderr => sub ($child, $chunk) { ... }

C<$chunk> is raw bytes from C<sysread()>; it is B<not> line-oriented and may split
arbitrarily. Buffer in user code if you want line/message framing.

By default, stdout/stderr pipes are only created if their callback is provided.

Override with:

  capture_stdout => 1|0
  capture_stderr => 1|0

Enabling capture without a callback drains and discards output so the child cannot
block on a full pipe.

=head2 Exit

  on_exit => sub ($child, $exit) { ... }

C<$exit> is a L<Linux::Event::Fork::Exit> object.

=head2 Stdin

=head3 One-shot stdin bytes

  stdin => $bytes

Creates a pipe, writes the bytes, and closes stdin.

=head3 Streaming stdin with backpressure

  stdin_pipe => 1

Creates a pipe and keeps it open. Stream with:

  $child->stdin_write($bytes);
  $child->close_stdin;

Writes are non-blocking and backpressure-aware.

SIGPIPE is ignored during writes and EPIPE is treated as a normal close condition.

=head2 Minimal timeout

  timeout    => $seconds,
  on_timeout => sub ($child) { ... },   # optional

When the timer fires and the child has not yet exited:

=over 4

=item 1. Calls C<on_timeout> (if provided)

=item 2. Sends TERM to the child once

=back

No escalation and no restart policy.

=head2 Child setup options

Applied in the child after stdio plumbing and before exec/callback:

  cwd       => "/path"
  umask     => 027
  env       => { KEY => "value", ... }   # overlays onto inherited %ENV
  clear_env => 1                         # start with empty %ENV before overlay

=head2 Metadata

  tag  => $label
  data => $opaque

Both are stored on the returned handle.

=head1 RETURN VALUE

Returns a L<Linux::Event::Fork::Child> handle.

=head1 SEE ALSO

L<Linux::Event>, L<Linux::Event::Fork::Child>, L<Linux::Event::Fork::Exit>

=head1 AUTHOR

Joshua S. Day (HAX)

=head1 LICENSE

Same terms as Perl itself.

=cut
