package Linux::Event::Fork;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.005';

use Carp qw(croak);
use POSIX ();
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

use Linux::Event::Fork::Child ();
use Linux::Event::Fork::Request ();

sub import ($class, %import) {
  my $loop_pkg = 'Linux::Event::Loop';

  no strict 'refs';

  # If called again with no options, don't clobber existing installed methods.
  if (!%import && defined &{"${loop_pkg}::fork"}) {
    # Still ensure fork_helper exists below.
  } else {
    *{"${loop_pkg}::fork"} = sub ($loop, %args) {
      my $fork = $loop->{_linux_event_fork} ||= $class->new(loop => $loop, %import);
      return $fork->_spawn(%args) if $fork->can('_spawn');
      return $fork->spawn(%args);
    };
  }

  *{"${loop_pkg}::fork_helper"} = sub ($loop, %args) {
  # Return the per-loop helper (create on first use).
  my $fork = $loop->{_linux_event_fork};

  if (!$fork) {
    $fork = $loop->{_linux_event_fork} = $class->new(loop => $loop, %import, %args);
    return $fork;
  }

  # Allow runtime reconfiguration (currently only max_children).
  if (%args) {
    my $max_children = delete $args{max_children};
    if (defined $max_children) {
      $max_children = 0 if !defined $max_children;
      croak "max_children must be a non-negative integer" if $max_children !~ /^\\d+$/;
      $fork->{max_children} = 0 + $max_children;
    }
    croak "unknown args: " . join(", ", sort keys %args) if %args;
  }

  return $fork;
};


  return;
}

sub new ($class, %args) {
  my $loop = delete $args{loop};
  croak "loop is required" if !$loop;

  my $max_children = delete $args{max_children};
  $max_children = 0 if !defined $max_children;
  croak "max_children must be a non-negative integer" if $max_children !~ /^\d+$/;

  croak "unknown args: " . join(", ", sort keys %args) if %args;

  return bless {
    loop => $loop,
    max_children => 0 + $max_children,
    running => 0,
    queue => [],
  }, $class;
}

sub loop ($self) { return $self->{loop} }
sub max_children ($self) { return $self->{max_children} }
sub running ($self) { return $self->{running} }
sub queued ($self) { return scalar @{ $self->{queue} } }

sub spawn ($self, %spec) {
  # Controlled parallelism: if max_children is set and we are at capacity,
  # enqueue the request and return a Request handle.
  if ($self->{max_children} && $self->{running} >= $self->{max_children}) {
    my $req = Linux::Event::Fork::Request->_new(fork => $self, spec => \%spec);
    push @{ $self->{queue} }, $req;
    return $req;
  }

  return $self->_spawn_now(\%spec);
}

sub _spawn_now ($self, $spec) {
  my %spec = %$spec;

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
  my $on_start   = delete $spec{on_start};

  my $tag  = delete $spec{tag};
  my $data = delete $spec{data};

  croak "on_stdout must be a coderef"  if defined($on_stdout)  && ref($on_stdout)  ne 'CODE';
  croak "on_stderr must be a coderef"  if defined($on_stderr)  && ref($on_stderr)  ne 'CODE';
  croak "on_exit must be a coderef"    if defined($on_exit)    && ref($on_exit)    ne 'CODE';
  croak "on_timeout must be a coderef" if defined($on_timeout) && ref($on_timeout) ne 'CODE';
  croak "on_start must be a coderef"   if defined($on_start)   && ref($on_start)   ne 'CODE';
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

  # Wrap on_exit so we always release capacity and start the next queued job,
  # even if user code throws.
  my $user_on_exit = $on_exit;
  my $managed = $self->{max_children} ? 1 : 0;

  $on_exit = sub ($child_obj, $exit_obj) {
    if ($user_on_exit) {
      eval { $user_on_exit->($child_obj, $exit_obj); 1 };
    }
    $self->_on_child_finished($child_obj) if $managed;
  };

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

    managed_by_fork => ($managed ? $self : undef),
  );

  $self->{running}++ if $managed;

  if ($on_start) {
    eval { $on_start->($handle); 1 };
  }

  if (defined $stdin && $stdin ne '') {
    $handle->stdin_write($stdin);
  }
  if (defined $stdin && !$stdin_pipe) {
    $handle->close_stdin;
  }

  $handle->_arm;
  return $handle;
}

sub _on_child_finished ($self, $child) {
  # Idempotent: a child should only finish once, but guard anyway.
  return if !$self->{running};
  $self->{running}--;

  # Start queued work, if any.
  while ($self->{max_children} && $self->{running} < $self->{max_children}) {
    my $req = shift @{ $self->{queue} } or last;
    next if $req->_canceled;
    $req->_start;
  }
  $self->_maybe_fire_drain;

  return;
}

sub drain ($self, %args) {
  my $on_done = delete $args{on_done};
  croak "on_done is required" if !defined $on_done;
  croak "on_done must be a coderef" if ref($on_done) ne 'CODE';
  croak "unknown args: " . join(", ", sort keys %args) if %args;

  $self->{_drain_on_done} = $on_done;

  $self->_maybe_fire_drain;

  return 1;
}

sub _maybe_fire_drain ($self) {
  my $cb = $self->{_drain_on_done} or return;

  return if $self->{running};
  return if @{ $self->{queue} };

  delete $self->{_drain_on_done};

  eval { $cb->($self); 1 };
  return;
}


sub cancel_queued ($self, $pred = undef) {
  croak "cancel_queued predicate must be a coderef" if defined($pred) && ref($pred) ne 'CODE';

  my $n = 0;
  my @keep;

  for my $req (@{ $self->{queue} }) {
    next if !defined $req;
    if (!$req->_canceled && (!defined($pred) || $pred->($req))) {
      $req->cancel;
      $n++;
      next;
    }
    push @keep, $req;
  }

  $self->{queue} = \@keep;

  $self->_maybe_fire_drain;

  return $n;
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

Linux::Event::Fork - Async child process management for Linux::Event

=head1 SYNOPSIS

  use v5.36;
  use Linux::Event;
  use Linux::Event::Fork;

  my $loop = Linux::Event->new;

  # Optional: configure bounded parallelism
  my $fork = $loop->fork_helper(max_children => 4);

  $loop->fork(
    cmd => [ $^X, '-we', 'print "hello\n"; exit 0' ],

    on_stdout => sub ($child, $chunk) {
      print $chunk;
    },

    on_exit => sub ($child, $exit) {
      print "exit code: " . $exit->code . "\n";
      $loop->stop;
    },
  );

  $loop->run;

=head1 DESCRIPTION

B<Linux::Event::Fork> is a small policy layer built on top of
L<Linux::Event>. It provides nonblocking child process management
integrated directly into the event loop.

Features include:

=over 4

=item * Nonblocking stdout/stderr capture

=item * Streaming stdin

=item * Soft timeouts

=item * Tagging

=item * Bounded parallelism (C<max_children>)

=item * Internal queueing

=item * C<drain()> callback

=item * C<cancel_queued()> support

=item * Introspection methods

=back

This module is intentionally minimal. It wires file descriptors,
tracks lifecycle, and optionally enforces concurrency limits.

=head1 CONFIGURATION

Configuration is performed at runtime:

  my $fork = $loop->fork_helper(max_children => 4);

The older compile-time idiom:

  use Linux::Event::Fork max_children => 4;

is intentionally removed.

=head1 SPAWNING CHILDREN

=head2 cmd => [ ... ]

The simplest form. Forks, wires FDs, then execs immediately.

  $loop->fork(cmd => [ 'ls', '-l' ]);

=head2 child => sub { ... }

Runs Perl code in the child after stdio plumbing.

  $loop->fork(
    child => sub {
      exec 'sh', '-c', 'echo hello';
      exit 127;
    },
  );

Returning from the callback is treated as failure.

=head1 BOUNDED PARALLELISM

  my $fork = $loop->fork_helper(max_children => 4);

When the pool is full, C<fork()> returns a
C<Linux::Event::Fork::Request> object instead of a running child.
Queued requests start automatically when capacity becomes available.

=head1 DRAIN

  $fork->drain(on_done => sub ($fork) {
    $loop->stop;
  });

The callback fires once when:

=over 4

=item * No children are running

=item * The queue is empty

=back

=head1 CANCEL QUEUED

  $fork->cancel_queued(sub ($req) {
    $req->tag eq 'low-priority';
  });

Only queued requests are affected. Running children are not modified.

=head1 INTROSPECTION

  $fork->running;
  $fork->queued;
  $fork->max_children;

=head1 WHAT THIS MODULE IS NOT

This is not:

=over 4

=item * A supervisor

=item * A job scheduler

=item * A framework

=back

It extends L<Linux::Event>; it does not replace it.

=head1 AUTHOR

Joshua S. Day

=head1 LICENSE

Same terms as Perl itself.

=cut
