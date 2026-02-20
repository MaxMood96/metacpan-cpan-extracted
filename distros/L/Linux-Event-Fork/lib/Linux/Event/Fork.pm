package Linux::Event::Fork;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.007';

use Carp qw(croak);
use POSIX ();
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

use Linux::Event::Fork::Child ();
use Linux::Event::Fork::Request ();


sub new ($class, $loop, %args) {
  croak "loop is required" if !$loop || !ref($loop);

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

sub loop ($self)    {return $self->{loop} }
sub running ($self) {return $self->{running} }
sub queued ($self)  {return scalar @{ $self->{queue} } }

sub max_children ($self, $new = undef) {
  if (defined $new) {
    croak "max_children must be a non-negative integer"
      if $new !~ /^\d+$/;

    $self->{max_children} = 0 + $new;

    # If we increased the limit, try to start queued work.
    while ($self->{max_children} && $self->{running} < $self->{max_children}) {
      my $req = shift @{ $self->{queue} } or last;
      next if $req->_canceled;
      $req->_start;
    }

    $self->_maybe_fire_drain;
  }

  return $self->{max_children};
}

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
  my $timeout_kill = delete $spec{timeout_kill};
  my $on_start   = delete $spec{on_start};

  my $tag  = delete $spec{tag};
  my $data = delete $spec{data};

  croak "on_stdout must be a coderef"  if defined($on_stdout)  && ref($on_stdout)  ne 'CODE';
  croak "on_stderr must be a coderef"  if defined($on_stderr)  && ref($on_stderr)  ne 'CODE';
  croak "on_exit must be a coderef"    if defined($on_exit)    && ref($on_exit)    ne 'CODE';
  croak "on_timeout must be a coderef" if defined($on_timeout) && ref($on_timeout) ne 'CODE';
  croak "on_start must be a coderef"   if defined($on_start)   && ref($on_start)   ne 'CODE';
  croak "timeout must be numeric seconds" if defined($timeout) && ref($timeout);
  croak "timeout_kill must be numeric seconds" if defined($timeout_kill) && ref($timeout_kill);

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

    timeout      => $timeout,

    timeout_kill => $timeout_kill,
    on_timeout     => $on_timeout,

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

Linux::Event::Fork - Child process management integrated with Linux::Event

=head1 SYNOPSIS

  use v5.36;
  use Linux::Event;
  use Linux::Event::Fork;

  my $loop   = Linux::Event->new;
  my $forker = Linux::Event::Fork->new($loop,
    max_children => 4,  # 0 = unlimited
  );

  my $h = $forker->spawn(
    cmd => [ $^X, '-we', 'print "hello\n"; exit 0' ],

    on_stdout => sub ($child, $chunk) {
      print $chunk;
    },

    on_exit => sub ($child, $exit) {
      printf "pid=%d exited=%d code=%d\n",
        $exit->pid, $exit->exited, ($exit->exited ? $exit->code : -1);
      $loop->stop;
    },
  );

  if ($h->isa('Linux::Event::Fork::Request')) {
    warn "queued\n";
  }

  $loop->run;

=head1 DESCRIPTION

Linux::Event::Fork runs child processes while integrating their lifecycle and
I/O streams (stdout/stderr/stdin) with a L<Linux::Event> loop.

Features:

=over 4

=item *
Nonblocking stdout/stderr capture (chunk callbacks)

=item *
Optional streaming stdin (parent -> child)

=item *
Timeout support with optional escalation to SIGKILL

=item *
Bounded parallelism (max_children) with queueing

=item *
Drain callback when all work completes

=item *
Cancel queued requests (bulk or per-request)

=item *
Introspection (running/queued/max_children)

=back

=head1 EXECUTION MODEL

All C<on_*> callbacks run in the B<parent process>, inside the event loop.

Only the C<child =E<gt> sub { ... }> callback runs in the B<child process>.

Stream directions:

  stdin   : parent -> child
  stdout  : child  -> parent
  stderr  : child  -> parent

There is no "on_stdin" callback. Stdin is a write stream to the child.

=head1 CONSTRUCTOR

=head2 new($loop, %args)

  my $forker = Linux::Event::Fork->new($loop,
    max_children => 4,   # optional (default 0 = unlimited)
  );

Constructs a forker bound to a specific event loop.

Arguments:

=over 4

=item max_children => $n

Maximum number of concurrently running children. C<0> means unlimited.

=back

=head1 METHODS

=head2 loop

  my $loop = $forker->loop;

Returns the underlying L<Linux::Event> loop.

=head2 spawn(%spec)

  my $h = $forker->spawn(%spec);

Starts a child immediately if capacity allows, otherwise enqueues the request.

Returns either:

=over 4

=item * L<Linux::Event::Fork::Child>

If started immediately.

=item * L<Linux::Event::Fork::Request>

If queued due to C<max_children>.

=back

=head3 spawn options

Exactly one of:

=over 4

=item cmd => \@argv

Execs the given argv in the child.

=item child => sub { ... }

Runs the coderef in the child process. If it returns, the child exits with 127.

=back

Optional:

=over 4

=item on_start => sub ($child) { ... }

Called in the parent after the child handle is created (and before the loop
has necessarily observed any I/O).

=item on_stdout => sub ($child, $chunk) { ... }

Called in the parent when the child writes to stdout.

=item on_stderr => sub ($child, $chunk) { ... }

Called in the parent when the child writes to stderr.

=item on_exit => sub ($child, $exit) { ... }

Called in the parent after the child has fully exited. C<$exit> is a
L<Linux::Event::Fork::Exit>.

=item capture_stdout => $bool

Force stdout capture on/off.
Default: true if C<on_stdout> is provided, otherwise false.

=item capture_stderr => $bool

Force stderr capture on/off.
Default: true if C<on_stderr> is provided, otherwise false.

=item stdin => $string

If provided, writes this string to the child's stdin after start.

=item stdin_pipe => $bool

If true, keeps stdin open for streaming writes using the child handle.
If false (default), stdin is closed after the initial C<stdin> write (if any).

=item timeout => $seconds

Soft timeout. When it fires: calls C<on_timeout> (if any) and sends SIGTERM.

=item on_timeout => sub ($child) { ... }

Called in the parent when C<timeout> fires.

=item timeout_kill => $seconds

If set, after SIGTERM waits this many seconds and then sends SIGKILL if still alive.

=item cwd => $dir

Changes working directory in the child before exec/callback.

=item umask => $mask

Sets umask in the child before exec/callback.

=item clear_env => $bool

If true, clears %ENV in the child before applying C<env>.

=item env => \%env

Merges these variables into %ENV in the child before exec/callback.

=item tag => $string

Opaque tag stored on the child/request handles.

=item data => $scalar

Opaque user data stored on the child/request handles.

=back

=head2 max_children([$n])

  my $n = $forker->max_children;
  $forker->max_children(8);

Get or set the concurrency limit.

C<0> means unlimited.

Increasing the limit may immediately start queued requests.
Decreasing the limit does not affect running children; it only limits future starts.

=head2 running

  my $n = $forker->running;

Number of children currently running (tracked for capacity control).

=head2 queued

  my $n = $forker->queued;

Number of queued requests waiting for capacity.

=head2 drain(on_done => sub ($forker) { ... })

  $forker->drain(on_done => sub ($forker) {
    ...
  });

Registers a callback that fires once when:

  running == 0
  AND
  queue is empty

If already drained at registration time, the callback fires immediately on the
next opportunity inside the loop.

=head2 cancel_queued([$predicate])

  my $n = $forker->cancel_queued;
  my $n = $forker->cancel_queued(sub ($req) { ... });

Cancels queued requests. If a predicate is provided, only queued requests for which
the predicate returns true are canceled.

Returns the number canceled.

=head1 RETURN OBJECTS

=head2 Linux::Event::Fork::Child

Represents a running (or exited) child process.

See L<Linux::Event::Fork::Child>.

=head2 Linux::Event::Fork::Request

Represents a queued spawn request that has not yet started.

See L<Linux::Event::Fork::Request>.

=head1 CAPACITY AND QUEUE MODEL

When C<max_children> is non-zero:

  running < max_children   -> spawn immediately (Child)
  running >= max_children  -> enqueue (Request)

When a child exits, capacity is released and queued requests start FIFO.

Changing C<max_children> at runtime affects future starts, and increasing the limit
may immediately start queued requests.

=head1 WHAT THIS MODULE IS NOT

This is not a supervisor, scheduler, or promise framework.

It is a deterministic process management layer for child processes built directly
on Linux::Event.

=head1 AUTHOR

Joshua S. Day

=head1 LICENSE

Same terms as Perl itself.

=cut
