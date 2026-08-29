package Linux::Event::Process;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use Errno ();
use Fcntl qw(F_GETFD F_GETFL F_SETFD F_SETFL FD_CLOEXEC O_NONBLOCK);
use POSIX qw(SIGKILL SIGRTMAX);
use Scalar::Util qw(blessed);
use utf8 ();

require Linux::Event::Loop;
use Linux::Event::Error;
require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my %CLASS_DESCRIPTOR;

sub _integer ($target, $name, $value, $minimum, $maximum = 2_147_483_647) {
    croak "$target $name must be an integer"
        if !defined($value) || ref($value) || $value !~ /\A\d+\z/;
    my $digits = "$value";
    $digits =~ s/\A0+(?=\d)//;
    croak "$target $name must be at most $maximum"
        if length($digits) > length("$maximum")
        || (length($digits) == length("$maximum")
            && $digits gt "$maximum");
    $value = 0 + $value;
    croak "$target $name must be at least $minimum" if $value < $minimum;
    return $value;
}

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Process is an abstract base class'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Process subclass"
        if !$class->isa(__PACKAGE__);
    my %callback = map { $_ => scalar $class->can($_) } qw(
        on_exit on_stdout on_stderr on_stdout_eof on_stderr_eof
        on_stdin_drain on_error
    );
    croak "$class must define on_exit()" if !$callback{on_exit};
    my %option = (
        read_size            => 65_536,
        max_reads_per_tick   => 64,
        stdin_high_watermark => 1_048_576,
        stdin_low_watermark  => 262_144,
        max_pending_stdin    => 0,
    );
    if (my $configure = $class->can('process_options')) {
        my @configured = $configure->($class);
        my %configured;
        if (@configured == 1 && ref($configured[0]) eq 'HASH') {
            %configured = %{ $configured[0] };
        } else {
            croak "$class process_options() returned an odd option list"
                if @configured % 2;
            %configured = @configured;
        }
        my @unknown = grep { !exists $option{$_} } keys %configured;
        croak "$class process_options() returned unknown options: "
            . join(', ', sort @unknown) if @unknown;
        @option{keys %configured} = values %configured;
    }
    $option{read_size} = _integer($class, 'read_size', $option{read_size}, 1);
    $option{max_reads_per_tick} = _integer(
        $class, 'max_reads_per_tick', $option{max_reads_per_tick}, 1,
    );
    for my $name (qw(stdin_high_watermark stdin_low_watermark
        max_pending_stdin)) {
        $option{$name} = _integer($class, $name, $option{$name}, 0);
    }
    croak "$class stdin_low_watermark must be <= stdin_high_watermark"
        if $option{stdin_low_watermark} > $option{stdin_high_watermark};
    return $CLASS_DESCRIPTOR{$class} = {
        class => $class, callbacks => \%callback, options => \%option,
    };
}

sub new ($class, %option) {
    croak 'new(): must be called as a class method' if ref $class;
    my $descriptor = _descriptor_for($class);
    my $loop = delete $option{loop};
    croak 'new(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $data = delete $option{data};
    my $pid = delete $option{pid};
    croak 'new(): pid is required' if !defined $pid;
    $pid = _integer('new():', 'pid', $pid, 1);
    my $reap = exists($option{reap}) ? delete($option{reap}) : 1;
    croak 'new(): reap must be zero or one'
        if !defined($reap) || ref($reap) || $reap !~ /\A[01]\z/;
    croak 'new(): unknown options: ' . join(', ', sort keys %option)
        if %option;
    my $self = $class->_new_object(
        descriptor => $descriptor, loop => $loop, data => $data,
        mode => 'observe', pid => $pid, reap => $reap ? 1 : 0,
    );
    return $self;
}

sub spawn ($class, %option) {
    croak 'spawn(): must be called as a class method' if ref $class;
    my $descriptor = _descriptor_for($class);
    my $loop = delete $option{loop};
    croak 'spawn(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $data = delete $option{data};
    my $command = delete $option{command};
    croak 'spawn(): command must be a nonempty array reference'
        if ref($command) ne 'ARRAY' || !@$command;
    my @command;
    for my $index (0 .. $#$command) {
        my $argument = $command->[$index];
        croak 'spawn(): every command argument must be a defined scalar'
            if !defined($argument) || ref($argument);
        croak 'spawn(): command arguments cannot contain NUL bytes'
            if "$argument" =~ /\0/;
        my $bytes = "$argument";
        croak 'spawn(): command arguments must be byte strings'
            if !utf8::downgrade($bytes, 1);
        croak 'spawn(): command executable must be a non-empty string'
            if $index == 0 && $bytes eq '';
        push @command, $bytes;
    }
    my $cwd = delete $option{cwd};
    croak 'spawn(): cwd must be a non-empty path'
        if defined($cwd) && (ref($cwd) || $cwd eq '' || $cwd =~ /\0/);
    if (defined $cwd) {
        $cwd = "$cwd";
        croak 'spawn(): cwd must be a byte-string path'
            if !utf8::downgrade($cwd, 1);
    }
    my $env = delete $option{env};
    if (defined $env) {
        croak 'spawn(): env must be a hash reference' if ref($env) ne 'HASH';
        my %copy;
        for my $name (keys %$env) {
            croak 'spawn(): environment names must be nonempty and cannot contain = or NUL'
                if $name eq '' || $name =~ /[=\0]/;
            my $value = $env->{$name};
            croak 'spawn(): environment values must be defined scalars without NUL'
                if !defined($value) || ref($value) || "$value" =~ /\0/;
            my ($byte_name, $byte_value) = ("$name", "$value");
            croak 'spawn(): environment names and values must be byte strings'
                if !utf8::downgrade($byte_name, 1)
                || !utf8::downgrade($byte_value, 1);
            $copy{$byte_name} = $byte_value;
        }
        $env = \%copy;
    }

    my %stdio;
    for my $name (qw(stdin stdout stderr)) {
        $stdio{$name} = exists($option{$name})
            ? delete($option{$name}) : 'inherit';
        _validate_stdio($name, $stdio{$name});
    }
    my %configured = %{ $descriptor->{options} };
    for my $name (keys %configured) {
        next if !exists $option{$name};
        $configured{$name} = delete $option{$name};
    }
    $configured{read_size} = _integer(
        'spawn():', 'read_size', $configured{read_size}, 1,
    );
    $configured{max_reads_per_tick} = _integer(
        'spawn():', 'max_reads_per_tick', $configured{max_reads_per_tick}, 1,
    );
    for my $name (qw(stdin_high_watermark stdin_low_watermark
        max_pending_stdin)) {
        $configured{$name} = _integer(
            'spawn():', $name, $configured{$name}, 0,
        );
    }
    croak 'spawn(): stdin_low_watermark must be <= stdin_high_watermark'
        if $configured{stdin_low_watermark}
        > $configured{stdin_high_watermark};
    croak 'spawn(): unknown options: ' . join(', ', sort keys %option)
        if %option;
    $descriptor = { %$descriptor, options => \%configured };

    my $callback = $descriptor->{callbacks};
    croak 'spawn(): on_stdout requires stdout => pipe'
        if $callback->{on_stdout} && $stdio{stdout} ne 'pipe';
    croak 'spawn(): on_stdout_eof requires stdout => pipe'
        if $callback->{on_stdout_eof} && $stdio{stdout} ne 'pipe';
    croak 'spawn(): on_stderr requires stderr => pipe'
        if $callback->{on_stderr} && $stdio{stderr} ne 'pipe';
    croak 'spawn(): on_stderr_eof requires stderr => pipe'
        if $callback->{on_stderr_eof} && $stdio{stderr} ne 'pipe';
    croak 'spawn(): on_stdin_drain requires stdin => pipe'
        if $callback->{on_stdin_drain} && $stdio{stdin} ne 'pipe';

    return $class->_new_object(
        descriptor => $descriptor, loop => $loop, data => $data,
        mode => 'spawn', command => \@command, cwd => $cwd, env => $env,
        stdio => \%stdio, reap => 1,
    );
}

sub _validate_stdio ($name, $value) {
    return if ref($value) && defined(fileno($value));
    croak "spawn(): $name must be inherit, pipe, null, or a filehandle"
        if !defined($value) || ref($value)
        || ($value ne 'inherit' && $value ne 'pipe' && $value ne 'null'
            && !($name eq 'stderr' && $value eq 'stdout'));
    return;
}

sub _new_object ($class, %argument) {
    my $loop = delete $argument{loop};
    my $self = bless {
        %argument,
        loop => undef,
        state => 'unattached',
        pidfd => undef,
        pid_watcher => undef,
        stdin_fh => undef,
        stdout_fh => undef,
        stderr_fh => undef,
        stdin_watcher => undef,
        stdout_watcher => undef,
        stderr_watcher => undef,
        stdin_queue => [],
        pending_stdin_bytes => 0,
        stdin_above_high => 0,
        stdin_closing => 0,
        stdin_closed => 0,
        stdout_closed => 1,
        stderr_closed => 1,
        exit_observed => 0,
        exit_code => undef,
        term_signal => undef,
        core_dumped => 0,
        raw_status => undef,
        last_error => undef,
    }, $class;
    $loop->add($self) if defined $loop;
    return $self;
}

sub _set_cloexec ($fh) {
    my $flags = fcntl($fh, F_GETFD, 0);
    die "fcntl(F_GETFD): $!" if !defined $flags;
    fcntl($fh, F_SETFD, $flags | FD_CLOEXEC)
        or die "fcntl(F_SETFD): $!";
    return;
}

sub _set_nonblocking ($fh) {
    my $flags = fcntl($fh, F_GETFL, 0);
    die "fcntl(F_GETFL): $!" if !defined $flags;
    fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or die "fcntl(F_SETFL): $!";
    return;
}

sub _pipe_for ($direction) {
    my ($read_fd, $write_fd) = @{ _pipe_cloexec() };
    my ($read, $write);
    if (!open($read, '<&=', $read_fd)) {
        my $failure = "$!";
        eval { _close_fd($read_fd) };
        eval { _close_fd($write_fd) };
        die "open pipe read handle: $failure";
    }
    if (!open($write, '>&=', $write_fd)) {
        my $failure = "$!";
        close $read;
        eval { _close_fd($write_fd) };
        die "open pipe write handle: $failure";
    }
    _set_cloexec($read);
    _set_cloexec($write);
    if ($direction eq 'stdin') {
        _set_nonblocking($write);
        return ($write, $read, [$read, $write]);
    }
    _set_nonblocking($read);
    return ($read, $write, [$read, $write]);
}

sub _attachment_error ($failure, $default_operation) {
    return $failure if blessed($failure)
        && $failure->isa('Linux::Event::Error');
    my $message = "$failure";
    $message =~ s/\s+\z//;
    my $operation = $default_operation;
    if ($message =~ s/\A([A-Za-z][A-Za-z0-9_]*)(?:\([^)]*\))?:\s*//) {
        $operation = $1;
    }
    return Linux::Event::Error->new(
        type => 'process', operation => $operation,
        message => $message || 'process setup failed',
    );
}

sub _stdio_source ($self, $name, $owned, $close_fds) {
    my $mode = $self->{stdio}{$name};
    return -1 if $mode eq 'inherit';
    return -2 if $name eq 'stderr' && $mode eq 'stdout';
    if ($mode eq 'pipe') {
        my ($parent, $child, $all) = _pipe_for($name);
        $self->{"${name}_fh"} = $parent;
        $self->{"${name}_closed"} = 0 if $name ne 'stdin';
        push @$owned, $child;
        push @$close_fds, map { fileno($_) } @$all;
        return fileno($child);
    }
    if ($mode eq 'null') {
        my $operator = $name eq 'stdin' ? '<' : '>';
        open(my $null, $operator, '/dev/null') or die "open /dev/null: $!";
        _set_cloexec($null);
        push @$owned, $null;
        push @$close_fds, fileno($null);
        return fileno($null);
    }
    my $fd = fileno($mode);
    push @$close_fds, $fd;
    return $fd;
}

sub _attach_to_loop ($self, $loop) {
    croak 'add(): Process is not unattached'
        if $self->{state} ne 'unattached' || $self->{loop};
    $self->{loop} = $loop;
    if ($self->{mode} eq 'observe') {
        my $pidfd = eval { _pidfd_open($self->{pid}) };
        if (!defined $pidfd) {
            my $failure = _attachment_error($@, 'pidfd_open');
            $self->{loop} = undef;
            die $failure;
        }
        $self->{pidfd} = $pidfd;
    } else {
        my (@owned, @close_fds);
        my ($stdin_fd, $stdout_fd, $stderr_fd);
        my $ok = eval {
            $stdin_fd = $self->_stdio_source('stdin', \@owned, \@close_fds);
            $stdout_fd = $self->_stdio_source('stdout', \@owned, \@close_fds);
            $stderr_fd = $self->_stdio_source('stderr', \@owned, \@close_fds);
            my $result = _spawn(
                $self->{command}, $self->{env}, $self->{cwd},
                $stdin_fd, $stdout_fd, $stderr_fd, \@close_fds,
            );
            ($self->{pid}, $self->{pidfd}) = @$result;
            1;
        };
        my $failure = $@;
        close $_ for @owned;
        if (!$ok) {
            close(delete $self->{stdin_fh}) if $self->{stdin_fh};
            close(delete $self->{stdout_fh}) if $self->{stdout_fh};
            close(delete $self->{stderr_fh}) if $self->{stderr_fh};
            $self->{loop} = undef;
            die _attachment_error($failure, 'spawn');
        }
    }
    $self->{state} = 'running';
    my $registered = eval { $self->_register_watchers; 1 };
    if (!$registered) {
        my $failure = $@ || 'could not register Process descriptors';
        if ($self->{mode} eq 'spawn' && defined $self->{pid}) {
            if (defined $self->{pidfd}) {
                eval { _pidfd_send($self->{pidfd}, SIGKILL); 1 };
            } else {
                kill SIGKILL, $self->{pid};
            }
            while (waitpid($self->{pid}, 0) < 0 && $! == Errno::EINTR()) { }
        }
        $self->{state} = 'failed';
        $self->_release_handles;
        $self->{loop} = undef;
        die _attachment_error($failure, 'watch');
    }
    return $self;
}

sub _register_watchers ($self) {
    my $loop = $self->{loop};
    $self->{pid_watcher} = $loop->watch(
        fd => $self->{pidfd}, _internal => 1, data => $self,
        read => \&_pid_ready, error => \&_pid_ready,
        _callback_data_arg => 1,
    );
    if ($self->{stdout_fh}) {
        $self->{stdout_watcher} = $loop->watch(
            fh => $self->{stdout_fh}, _internal => 1, data => $self,
            read => \&_stdout_ready, error => \&_stdout_ready,
            _callback_data_arg => 1,
        );
    }
    if ($self->{stderr_fh}) {
        $self->{stderr_watcher} = $loop->watch(
            fh => $self->{stderr_fh}, _internal => 1, data => $self,
            read => \&_stderr_ready, error => \&_stderr_ready,
            _callback_data_arg => 1,
        );
    }
    if ($self->{stdin_fh}) {
        if ($self->{stdin_closed}) {
            close delete $self->{stdin_fh};
        } else {
            $self->{stdin_watcher} = $loop->watch(
                fh => $self->{stdin_fh}, _internal => 1, data => $self,
                write => \&_stdin_ready, error => \&_stdin_error,
                _callback_data_arg => 1,
            );
            $self->{stdin_watcher}->disable_write
                if !@{ $self->{stdin_queue} };
            $self->_flush_stdin;
        }
    }
    return;
}

sub _stdout_ready ($self) { $self->_read_output('stdout', 0) }
sub _stderr_ready ($self) { $self->_read_output('stderr', 0) }

sub _read_output ($self, $name, $unbounded) {
    my $fh = $self->{"${name}_fh"} or return;
    my $maximum = $unbounded ? 0 : $self->{descriptor}{options}{max_reads_per_tick};
    my $reads = 0;
    while (!$maximum || $reads++ < $maximum) {
        my $count = sysread(
            $fh, my $bytes, $self->{descriptor}{options}{read_size},
        );
        if (defined($count) && $count > 0) {
            my $callback = $self->{descriptor}{callbacks}{"on_$name"};
            $callback->($self, $bytes) if $callback;
            next;
        }
        if (defined($count) && $count == 0) {
            $self->_close_output($name, 1);
            last;
        }
        last if $! == Errno::EAGAIN() || $! == Errno::EWOULDBLOCK();
        my $errno = 0 + $!;
        $self->_close_output($name, 1);
        $self->_report(Linux::Event::Error->new(
            type => 'process_io', operation => "read_$name", errno => $errno,
            message => _message($errno),
        ));
        last;
    }
    return;
}

sub _close_output ($self, $name, $fire_eof) {
    if (my $watcher = delete $self->{"${name}_watcher"}) {
        $watcher->cancel;
    }
    if (my $fh = delete $self->{"${name}_fh"}) {
        close $fh;
    }
    return if $self->{"${name}_closed"}++;
    my $callback = $self->{descriptor}{callbacks}{"on_${name}_eof"};
    $callback->($self) if $fire_eof && $callback;
    return;
}

sub write_stdin ($self, $bytes) {
    croak 'write_stdin(): stdin is not configured as a pipe'
        if $self->{mode} ne 'spawn' || $self->{stdio}{stdin} ne 'pipe';
    croak 'write_stdin(): stdin is closing or closed'
        if $self->{stdin_closing} || $self->{stdin_closed};
    croak 'write_stdin(): bytes must be a defined scalar'
        if !defined($bytes) || ref($bytes);
    $bytes = "$bytes";
    croak 'write_stdin(): bytes must be a byte string'
        if !utf8::downgrade($bytes, 1);
    return 1 if $bytes eq '';
    if ($self->{stdin_fh} && !@{ $self->{stdin_queue} }) {
        my ($written, $errno) = _write_pipe(fileno($self->{stdin_fh}), $bytes);
        return 1 if $written == length($bytes);
        if ($written > 0) {
            $bytes = substr($bytes, $written);
        } elsif ($errno != Errno::EAGAIN() && $errno != Errno::EWOULDBLOCK()) {
            $self->_stdin_failure($errno);
            return undef;
        }
    }
    return $self->_queue_stdin($bytes);
}

sub _queue_stdin ($self, $bytes) {
    my $pending = $self->{pending_stdin_bytes} + length($bytes);
    my $limit = $self->{descriptor}{options}{max_pending_stdin};
    if ($limit && $pending > $limit) {
        my $error = Linux::Event::Error->new(
            type => 'output_limit', operation => 'write_stdin',
            message => "pending stdin would exceed $limit bytes",
            pending_bytes => $pending, limit => $limit,
        );
        $self->_close_stdin_handle;
        $self->_report($error);
        return undef;
    }
    push @{ $self->{stdin_queue} }, $bytes;
    $self->{pending_stdin_bytes} = $pending;
    $self->{stdin_above_high} = 1
        if $pending > $self->{descriptor}{options}{stdin_high_watermark};
    $self->{stdin_watcher}->enable_write if $self->{stdin_watcher};
    return $self->{stdin_above_high} ? 0 : 1;
}

sub _stdin_ready ($self) { $self->_flush_stdin }
sub _stdin_error ($self) { $self->_stdin_failure(Errno::EPIPE()) }

sub _flush_stdin ($self) {
    my $fh = $self->{stdin_fh} or return;
    while (defined(my $bytes = $self->{stdin_queue}[0])) {
        my ($written, $errno) = _write_pipe(fileno($fh), $bytes);
        if ($written == length($bytes)) {
            shift @{ $self->{stdin_queue} };
            $self->{pending_stdin_bytes} -= length($bytes);
            next;
        }
        if ($written > 0) {
            substr($self->{stdin_queue}[0], 0, $written, '');
            $self->{pending_stdin_bytes} -= $written;
            next;
        }
        last if $errno == Errno::EAGAIN() || $errno == Errno::EWOULDBLOCK();
        $self->_stdin_failure($errno);
        return;
    }
    $self->{stdin_watcher}->disable_write
        if $self->{stdin_watcher} && !@{ $self->{stdin_queue} };
    if ($self->{stdin_above_high}
        && $self->{pending_stdin_bytes}
            <= $self->{descriptor}{options}{stdin_low_watermark}) {
        $self->{stdin_above_high} = 0;
        my $callback = $self->{descriptor}{callbacks}{on_stdin_drain};
        $callback->($self) if $callback;
    }
    $self->_close_stdin_handle
        if $self->{stdin_closing} && !@{ $self->{stdin_queue} };
    return;
}

sub _stdin_failure ($self, $errno) {
    $self->_close_stdin_handle;
    $self->_report(Linux::Event::Error->new(
        type => 'process_io', operation => 'write_stdin', errno => $errno,
        message => _message($errno),
    ));
    return;
}

sub _close_stdin_handle ($self) {
    if (my $watcher = delete $self->{stdin_watcher}) {
        $watcher->cancel;
    }
    if (my $fh = delete $self->{stdin_fh}) {
        close $fh;
    }
    $self->{stdin_closed} = 1;
    $self->{stdin_queue} = [];
    $self->{pending_stdin_bytes} = 0;
    return;
}

sub close_stdin ($self) {
    croak 'close_stdin(): stdin is not configured as a pipe'
        if $self->{mode} ne 'spawn' || $self->{stdio}{stdin} ne 'pipe';
    return $self if $self->{stdin_closing} || $self->{stdin_closed};
    $self->{stdin_closing} = 1;
    $self->_close_stdin_handle
        if $self->{stdin_fh} && !@{ $self->{stdin_queue} };
    return $self;
}

sub _pid_ready ($self) {
    return if $self->{state} ne 'running';
    if ($self->{reap}) {
        my $status = eval { _pidfd_reap($self->{pidfd}) };
        if ($@) {
            my $message = "$@";
            $self->_runtime_fail(Linux::Event::Error->new(
                type => 'process', operation => 'waitid',
                message => $message,
            ));
            return;
        }
        return if !defined $status;
        my ($code, $value) = @$status;
        if ($code == 1) {
            $self->{exit_code} = $value;
            $self->{raw_status} = $value << 8;
        } elsif ($code == 2 || $code == 3) {
            $self->{term_signal} = $value;
            $self->{core_dumped} = $code == 3 ? 1 : 0;
            $self->{raw_status} = $value | ($code == 3 ? 0x80 : 0);
        }
    }
    $self->{exit_observed} = 1;
    if (my $watcher = delete $self->{pid_watcher}) {
        $watcher->cancel;
    }
    if (defined(my $pidfd = delete $self->{pidfd})) {
        _close_fd($pidfd);
    }
    $self->_close_stdin_handle if !$self->{stdin_closed};
    my $failure;
    for my $name (qw(stdout stderr)) {
        my $drained = eval {
            $self->_read_output($name, 1) if $self->{"${name}_fh"};
            $self->_close_output($name, 1) if $self->{"${name}_fh"};
            1;
        };
        $failure //= $@ if !$drained;
        $self->_close_output($name, 0) if $self->{"${name}_fh"};
    }
    $self->{state} = 'exited';
    my $callback = $self->{descriptor}{callbacks}{on_exit};
    my $called = eval { $callback->($self); 1 };
    $failure //= $@ if !$called;
    $self->{loop} = undef;
    die $failure if defined $failure;
    return;
}

sub _message ($errno) { local $! = $errno; return "$!" }

sub _report ($self, $error) {
    $self->{last_error} = $error;
    if (my $callback = $self->{descriptor}{callbacks}{on_error}) {
        $callback->($self, $error);
    } else {
        warn "$error\n";
    }
    return;
}

sub _runtime_fail ($self, $error) {
    $self->{state} = 'failed';
    $self->_release_handles;
    my $reported = eval { $self->_report($error); 1 };
    my $failure = $@;
    $self->{loop} = undef;
    die $failure if !$reported;
    return;
}

sub _release_handles ($self) {
    for my $name (qw(pid stdin stdout stderr)) {
        if (my $watcher = delete $self->{"${name}_watcher"}) {
            $watcher->cancel;
        }
    }
    if (defined(my $pidfd = delete $self->{pidfd})) {
        eval { _close_fd($pidfd) };
    }
    for my $name (qw(stdin stdout stderr)) {
        close delete $self->{"${name}_fh"} if $self->{"${name}_fh"};
    }
    $self->{stdin_queue} = [];
    $self->{pending_stdin_bytes} = 0;
    $self->{stdin_above_high} = 0;
    return;
}

sub signal ($self, $number) {
    croak 'signal(): Process is not running'
        if $self->{state} ne 'running' || !defined($self->{pidfd});
    croak 'signal(): signal must be a positive integer'
        if !defined($number) || ref($number) || $number !~ /\A\d+\z/
        || $number == 0;
    my $sent = eval {
        croak 'signal(): signal must be a valid Linux signal number'
            if $number > SIGRTMAX;
        _pidfd_send($self->{pidfd}, 0 + $number);
        1;
    };
    if (!$sent) {
        my $message = "$@";
        $message =~ s/\s+\z//;
        die Linux::Event::Error->new(
            type      => 'process',
            operation => 'signal',
            message   => $message || 'pidfd signal failed',
        );
    }
    return $self;
}

sub pid ($self) { $self->{pid} }
sub loop ($self) { $self->{loop} }
sub state ($self) { $self->{state} }
sub last_error ($self) { $self->{last_error} }
sub raw_status ($self) { $self->{raw_status} }
sub exit_code ($self) { $self->{exit_code} }
sub term_signal ($self) { $self->{term_signal} }
sub core_dumped ($self) { !!$self->{core_dumped} }
sub exited ($self) { $self->{state} eq 'exited' }
sub is_running ($self) { $self->{state} eq 'running' }
sub is_terminal ($self) {
    return $self->{state} eq 'exited' || $self->{state} eq 'failed';
}
sub pending_stdin_bytes ($self) { $self->{pending_stdin_bytes} }

sub data ($self, @argument) {
    $self->{data} = $argument[0] if @argument;
    return $self->{data};
}

sub CLONE_SKIP ($class) { 1 }

sub DESTROY ($self) {
    $self->_release_handles if !$self->is_terminal;
    return;
}

1;

__END__

=head1 NAME

Linux::Event::Process - pidfd process lifecycle and asynchronous standard I/O

=head1 SYNOPSIS

  package LE::Compiler;
  use parent 'Linux::Event::Process';

  sub on_stdout ($process, $bytes) {
      print "compiler: $bytes";
  }

  sub on_stderr ($process, $bytes) {
      warn "compiler: $bytes";
  }

  sub on_exit ($process) {
      if (defined(my $code = $process->exit_code)) {
          say "compiler exited with $code";
      } else {
          say "compiler received signal " . $process->term_signal;
      }
  }

  package main;
  my $process = $loop->add(LE::Compiler->spawn(
      command => ['/usr/bin/cc', '-c', 'example.c'], # required
      stdin   => 'pipe',                             # optional; default inherit
      stdout  => 'pipe',                             # optional; default inherit
      stderr  => 'pipe',                             # optional; default inherit
      data    => $build_state,                       # optional
  ));

=head1 DESCRIPTION

Process is the subclassing boundary for Linux pidfd lifecycle notification.
It can spawn a child with asynchronously managed standard I/O or observe an
existing PID. One Process owns the pidfd, pipe registrations, exit status, and
application data as one logical object.

Spawning uses native C<posix_spawnp>; Linux::Event does not run Perl code in a
post-fork child. This remains safe after the Loop's resolver workers have
started.

=head1 SPAWNING

  my $process = LE::Worker->spawn(
      loop    => $loop,                         # optional: attach immediately
      command => ['/usr/bin/worker', '--once'], # required
      cwd     => '/srv/application',            # optional
      env     => { MODE => 'production' },      # optional: replacement env
      stdin   => 'pipe',                        # optional; default inherit
      stdout  => 'pipe',                        # optional; default inherit
      stderr  => 'stdout',                      # optional; default inherit
      data    => $state,                        # optional
  );

C<command> is always a nonempty array reference and is passed directly to
C<posix_spawnp>. No implicit shell exists. Use an explicit
C<['/bin/sh', '-c', $script]> command when shell interpretation is intended.
Command arguments, C<cwd>, and environment names and values are operating-
system byte strings; encode character text before supplying them.

Each standard descriptor accepts C<inherit>, C<pipe>, C<null>, or an existing
filehandle. C<stderr> additionally accepts C<stdout>. C<env> replaces the
child environment rather than merging it. Omit C<env> to inherit the current
environment.

Construction is detached and side-effect free. The child starts when Process
attaches through C<loop =E<gt> $loop> or C<< $loop->add($process) >>.

=head1 OBSERVING AN EXISTING PROCESS

  my $child = $loop->add(LE::Child->new(
      pid  => $pid, # required
      reap => 1,    # default
      data => $data, # optional
  ));

C<reap =E<gt> 1> requires the PID to be a child of this process and supplies
exit details. Use C<reap =E<gt> 0> for a non-child; pidfd still reports
termination, but status accessors remain undefined.

=head1 CALLBACKS

  sub on_exit ($process) {                         # required
      say "child " . $process->pid . " finished";
      $process->loop->stop;
  }

  sub on_stdout ($process, $bytes) {               # optional with stdout pipe
      print "stdout: $bytes";
  }

  sub on_stderr ($process, $bytes) {               # optional with stderr pipe
      warn "stderr: $bytes";
  }

  sub on_stdout_eof ($process) {                   # optional with stdout pipe
      $process->data->{stdout_eof} = 1 if $process->data;
  }

  sub on_stderr_eof ($process) {                   # optional with stderr pipe
      $process->data->{stderr_eof} = 1 if $process->data;
  }

  sub on_stdin_drain ($process) {                  # optional with stdin pipe
      $process->data->{stdin_blocked} = 0 if $process->data;
  }

  sub on_error ($process, $error) {                # optional
      warn "$error\n";
  }

Callback CVs are resolved once per subclass. C<on_exit> runs once after native
reaping and after buffered stdout and stderr have been drained. The Process
still exposes its Loop during that callback.

Define an output or EOF callback only when the corresponding descriptor uses
C<pipe>. Define C<on_stdin_drain> only with C<stdin =E<gt> 'pipe'>. Process
rejects an impossible callback/stdio combination during construction rather
than silently omitting events. Without C<on_error>, asynchronous pipe failures
are warned and remain available through C<last_error>.

=head1 CLASS POLICY

  sub process_options ($class) {
      return (
          read_size            => 65_536,    # default
          max_reads_per_tick   => 64,        # default
          stdin_high_watermark => 1_048_576, # default
          stdin_low_watermark  => 262_144,   # default
          max_pending_stdin    => 0,         # default: unlimited
      );
  }

Constructor values override these cached defaults for one spawned Process.

=head1 STANDARD INPUT

=head2 write_stdin($bytes)

Writes immediately when possible and queues the remainder. It returns false
after accepted output exceeds the high watermark. A configured hard limit
closes Process stdin and reports C<output_limit> through C<on_error>. A prefix
written directly before the unsent remainder exceeds the limit cannot be
recalled. Input must be a byte string.

=head2 close_stdin

Finishes queued input, closes the parent's pipe end, and then delivers EOF to
the child. New writes are rejected after closing begins. It does not terminate
the Process.

=head2 pending_stdin_bytes

Returns the number of queued bytes.

=head1 PROCESS CONTROL

=head2 signal($number)

Sends a positive signal number through C<pidfd_send_signal> and returns the
Process. This avoids PID-reuse races. A failed request throws a structured
C<process> L<Linux::Event::Error> with operation C<signal>.

There is deliberately no ambiguous C<cancel> method. Signalling a process,
closing its input, and observing its eventual exit are separate operations.

=head1 STATUS

=head2 pid / state / is_running / is_terminal / exited

Return identity and lifecycle information. States are C<unattached>,
C<running>, C<exited>, and C<failed>.

=head2 exit_code / term_signal / core_dumped / raw_status

After a reaped exit, return decoded and conventional raw wait-status details.
Fields that do not apply are undef or false.

=head2 loop / data([$value]) / last_error

Return or update ordinary Process context.

=head1 OWNERSHIP

The Loop retains a running Process. Releasing an application reference does
not kill it. Destroying a Loop or interpreter closes Linux::Event descriptors
but never secretly signals a child. Applications must keep the Loop alive or
establish their own shutdown policy until every owned child has been reaped.

A spawned Process, or an observed child with C<reap =E<gt> 1>, owns that
child's wait status. Do not concurrently call C<wait>, C<waitpid>, or run a
separate C<SIGCHLD> reaper for the same PID. C<reap =E<gt> 0> is the
notification-only form when another component owns reaping.

=head1 PLATFORM

Process requires Linux pidfds and C<waitid(P_PIDFD)>; Linux 5.4 or newer is the
supported runtime. The build also requires a libc providing
C<posix_spawn_file_actions_addchdir_np>, which makes C<cwd> available without
running Perl code after C<fork>. These requirements are checked at build or
reported explicitly by the pidfd operation.

=cut
