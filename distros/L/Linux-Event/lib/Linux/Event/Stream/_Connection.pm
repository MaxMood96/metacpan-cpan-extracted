package Linux::Event::Stream::_Connection;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use Errno ();
use POSIX qw(isfinite);
use Scalar::Util qw(blessed refaddr);
use Socket qw(
    AF_INET AF_INET6 AF_UNIX
    SOCK_STREAM SOCK_NONBLOCK SOCK_CLOEXEC
    SOL_SOCKET SO_ERROR
    inet_pton
    pack_sockaddr_in pack_sockaddr_in6 pack_sockaddr_un
);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event::Error;
use Linux::Event::_Resolver ();
use Linux::Event::Address;
use Linux::Event::_SocketConfig ();

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub _introspection_owner ($self) { $self->{stream} }

sub _timeout ($value) {
    $value = 10 if !defined $value;
    croak 'new(): timeout must be a non-negative number of seconds'
        if ref($value)
        || $value !~ /\A(?:\d+(?:\.\d*)?|\.\d+)\z/
        || $value < 0;
    $value = 0 + $value;
    croak 'new(): timeout must be a finite number of seconds'
        if !isfinite($value);
    croak 'new(): timeout exceeds the supported timer range'
        if $value > 2_147_483_647;
    return $value;
}

sub _target_error_fields ($self) {
    return (
        host   => $self->{host},
        port   => $self->{port},
        path   => $self->{unix},
        family => $self->{family},
        attempts => $self->{attempt_count},
    );
}

sub _error ($self, %arg) {
    return Linux::Event::Error->new(
        _target_error_fields($self),
        %arg,
    );
}

sub _system_message ($errno) {
    local $! = $errno;
    return "$!";
}

sub new ($class, %opt) {
    croak 'new(): must be called as a class method' if ref $class;
    croak 'new(): internal connection must be created for a Stream'
        if $class ne __PACKAGE__;
    my $loop = delete $opt{loop};
    croak 'new(): loop must be an object implementing add(), watch(), and watch_fd()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch') || !$loop->can('watch_fd'));
    my $stream = delete $opt{stream};
    croak 'new(): stream must be a Linux::Event::Stream object'
        if !ref($stream) || !$stream->isa('Linux::Event::Stream');
    my $timeout = _timeout(delete $opt{timeout});
    my $socket_policy = delete $opt{socket_policy};
    croak 'new(): internal socket_policy must be a hash reference'
        if ref($socket_policy) ne 'HASH';
    my $bind_device = delete $opt{bind_device};
    croak 'new(): bind_device must be a non-empty interface name'
        if defined($bind_device)
        && (ref($bind_device) || $bind_device eq '' || $bind_device =~ /\0/);
    my $has_local_host = exists $opt{local_host};
    my $local_host = delete $opt{local_host};
    my $has_local_port = exists $opt{local_port};
    my $local_port = delete $opt{local_port};
    $local_port = 0 if !$has_local_port;
    croak 'new(): local_port must be an integer between 0 and 65535'
        if !defined($local_port) || ref($local_port)
        || $local_port !~ /\A\d+\z/
        || $local_port > 65535;
    my ($local_family, $local_packed);
    if ($has_local_host) {
        croak 'new(): local_host must be a non-empty numeric IP address'
            if !defined($local_host) || ref($local_host) || $local_host eq '';
        $local_packed = inet_pton(AF_INET, $local_host);
        $local_family = AF_INET if defined $local_packed;
        if (!defined $local_packed) {
            $local_packed = inet_pton(AF_INET6, $local_host);
            $local_family = AF_INET6 if defined $local_packed;
        }
        croak 'new(): local_host must be a numeric IPv4 or IPv6 address'
            if !defined $local_family;
    }

    my $host_mode = exists($opt{host}) || exists($opt{port});
    my $unix_mode = exists $opt{unix};
    my $sockaddr_mode = exists $opt{sockaddr};
    my $mode_count = ($host_mode ? 1 : 0) + ($unix_mode ? 1 : 0)
        + ($sockaddr_mode ? 1 : 0);
    croak 'new(): exactly one address mode is required '
        . '(host/port, unix, or sockaddr)'
        if $mode_count != 1;

    my ($host, $port, $unix, $sockaddr, $family);
    if ($host_mode) {
        $host = delete $opt{host};
        $port = delete $opt{port};
        croak 'new(): host is required' if !defined $host;
        croak 'new(): host must be a non-empty string without NUL bytes'
            if ref($host) || $host eq '' || $host =~ /\0/;
        croak 'new(): port is required' if !defined $port;
        croak 'new(): port must be an integer'
            if ref($port) || $port !~ /\A\d+\z/;
        $port = 0 + $port;
        croak 'new(): port must be between 0 and 65535'
            if $port < 0 || $port > 65535;
        croak 'new(): family is not allowed with host/port'
            if exists $opt{family};
    } elsif ($unix_mode) {
        $unix = delete $opt{unix};
        croak 'new(): unix must be a non-empty path without NUL bytes'
            if !defined($unix) || ref($unix) || $unix eq '' || $unix =~ /\0/;
        croak 'new(): family is not allowed with unix'
            if exists $opt{family};
        croak 'new(): local_host, local_port, and bind_device are not valid '
            . 'for Unix connections'
            if $has_local_host || $has_local_port || defined $bind_device;
    } else {
        $sockaddr = delete $opt{sockaddr};
        $family = delete $opt{family};
        croak 'new(): sockaddr must be a defined scalar'
            if !defined($sockaddr) || ref($sockaddr);
        croak 'new(): family is required with sockaddr'
            if !defined $family;
        croak 'new(): family must be a non-negative integer'
            if ref($family) || $family !~ /\A\d+\z/;
        $family = 0 + $family;
        croak 'new(): local_host, local_port, and bind_device require an '
            . 'IPv4 or IPv6 sockaddr'
            if ($has_local_host || $has_local_port || defined $bind_device)
            && $family != AF_INET && $family != AF_INET6;
    }
    croak 'new(): unknown options: ' . join(', ', sort keys %opt) if %opt;

    my $self = bless {
        loop          => undef,
        stream        => $stream,
        timeout       => $timeout,
        host          => $host,
        port          => $port,
        unix          => $unix,
        sockaddr      => $sockaddr,
        family        => $family,
        state         => 'detached',
        error         => undef,
        candidates    => [],
        candidate_at  => 0,
        attempts      => {},
        attempt_count => 0,
        next_attempt  => 1,
        last_errno    => undef,
        last_operation => undef,
        socket_policy => $socket_policy,
        bind_device   => $bind_device,
        local_host    => $local_host,
        local_port    => 0 + $local_port,
        local_bind    => ($has_local_host || $has_local_port) ? 1 : 0,
        local_family  => $local_family,
        local_packed  => $local_packed,
        compatible_candidate_seen => 0,
        timer_fd      => undef,
        timer_watcher => undef,
        pending_result => undef,
        deadline_at   => undef,
        fallback_at   => undef,
        resolver      => undef,
        resolver_request => undef,
        needs_resolution => 0,
    }, $class;

    $self->_resolve_candidates;
    $self->_attach_to_loop($loop) if $loop;
    return $self;
}

sub loop       ($self) { $self->{loop} }
sub host       ($self) { $self->{host} }
sub port       ($self) { $self->{port} }
sub path       ($self) { $self->{unix} }
sub family     ($self) { $self->{family} }
sub timeout    ($self) { $self->{timeout} }
sub state      ($self) { $self->{state} }
sub error      ($self) { $self->{error} }
sub attempts   ($self) { $self->{attempt_count} }
sub is_pending ($self) { $self->{state} eq 'pending' }
sub is_done    ($self) {
    return $self->{state} eq 'connected' || $self->{state} eq 'failed'
        || $self->{state} eq 'cancelled';
}
sub is_terminal ($self) { $self->is_done }

sub _attach_to_loop ($self, $loop) {
    croak 'add(): Stream connection is not detached'
        if $self->{state} ne 'detached' || $self->{loop};
    $self->{loop} = $loop;
    $self->{state} = 'pending';
    my $attached = eval {
        $self->{deadline_at} = _now() + $self->{timeout}
            if $self->{timeout} > 0;
        $self->_rearm_timer if defined $self->{deadline_at};
        if ($self->{pending_result}) {
            $self->_rearm_timer;
        } elsif ($self->{needs_resolution}) {
            $self->_start_resolution;
        } else {
            $self->_attempt_next;
        }
        1;
    };
    if (!$attached) {
        my $failure = $@ || 'connection attachment failed';
        eval { $self->_cancel_resolution; 1 };
        eval { $self->_close_attempts; 1 };
        eval { $self->_close_timer; 1 };
        $self->{loop} = undef;
        $self->{state} = 'detached';
        $self->{pending_result} = undef;
        $self->{deadline_at} = undef;
        $self->{fallback_at} = undef;
        $self->{candidate_at} = 0;
        $self->{attempt_count} = 0;
        $self->{last_errno} = undef;
        $self->{last_operation} = undef;
        $self->{compatible_candidate_seen} = 0;
        die $failure;
    }
    return $self;
}

sub cancel ($self) {
    return 0 if $self->is_done;
    $self->{state} = 'cancelled';
    $self->{pending_result} = undef;
    $self->_cancel_resolution;
    $self->_close_attempts;
    $self->_close_timer;
    return 1;
}

sub _resolve_candidates ($self) {
    if (defined $self->{unix}) {
        push @{ $self->{candidates} }, {
            family   => AF_UNIX,
            protocol => 0,
            sockaddr => pack_sockaddr_un($self->{unix}),
        };
        return;
    }
    if (defined $self->{sockaddr}) {
        push @{ $self->{candidates} }, {
            family   => $self->{family},
            protocol => 0,
            sockaddr => $self->{sockaddr},
        };
        return;
    }

    my $literal = $self->{host};
    $literal =~ s/\A[ \t\r\n]+//;
    $literal =~ s/[ \t\r\n]+\z//;
    if (length($literal) >= 2 && substr($literal, 0, 1) eq '['
        && substr($literal, -1, 1) eq ']') {
        $literal = substr($literal, 1, length($literal) - 2);
    }

    my $packed4 = inet_pton(AF_INET, $literal);
    if (defined $packed4) {
        push @{ $self->{candidates} }, {
            family   => AF_INET,
            protocol => 0,
            sockaddr => pack_sockaddr_in($self->{port}, $packed4),
        };
        return;
    }
    my $packed6 = inet_pton(AF_INET6, $literal);
    if (defined $packed6) {
        push @{ $self->{candidates} }, {
            family   => AF_INET6,
            protocol => 0,
            sockaddr => pack_sockaddr_in6($self->{port}, $packed6),
        };
        return;
    }

    $self->{needs_resolution} = 1;
    return;
}

sub _now () { clock_gettime(CLOCK_MONOTONIC) }

sub _start_resolution ($self) {
    return if $self->{state} ne 'pending' || $self->{resolver_request};
    my $resolver = Linux::Event::_Resolver->for_loop($self->{loop});
    $self->{resolver} = $resolver;
    my $id = eval { $resolver->submit($self, $self->{host}, $self->{port}) };
    if (!$id) {
        my $message = $@ || 'could not submit hostname resolution';
        $self->_queue_error($self->_error(
            type             => 'resolve',
            operation        => 'resolve',
            errno            => Errno::EIO(),
            message          => $message,
            resolver_message => $message,
        ));
        return;
    }
    $self->{resolver_request} = $id;
    $self->_rearm_timer;
    return;
}

sub _cancel_resolution ($self) {
    my $id = delete $self->{resolver_request};
    my $resolver = delete $self->{resolver};
    $resolver->cancel($id) if $resolver && defined $id;
    return;
}

sub _resolver_completed ($self, $result) {
    return if $self->{state} ne 'pending';
    return if !defined($self->{resolver_request})
        || $result->{id} != $self->{resolver_request};
    delete $self->{resolver_request};
    delete $self->{resolver};

    if ($result->{error_code}) {
        my $message = $result->{message} || 'hostname resolution failed';
        my $errno = $result->{system_errno} || Errno::ENOENT();
        $self->_queue_error($self->_error(
            type             => 'resolve',
            operation        => 'resolve',
            errno            => $errno,
            message          => $message,
            resolver_message => $message,
        ));
        return;
    }

    $self->{candidates} = _happy_eyeballs_order($result->{candidates});
    if (!@{ $self->{candidates} }) {
        $self->_queue_error($self->_error(
            type      => 'resolve',
            operation => 'resolve',
            errno     => Errno::ENOENT(),
            message   => 'hostname resolution returned no stream addresses',
        ));
        return;
    }
    $self->{candidate_at} = 0;
    $self->_attempt_next;
    return;
}

sub _happy_eyeballs_order ($input) {
    my (@v4, @v6, @other);
    for my $candidate (@$input) {
        next if !defined($candidate->{family})
            || !defined($candidate->{sockaddr});
        if ($candidate->{family} == AF_INET) {
            push @v4, $candidate;
        } elsif ($candidate->{family} == AF_INET6) {
            push @v6, $candidate;
        } else {
            push @other, $candidate;
        }
    }
    my $first_family = @$input && $input->[0]{family} == AF_INET
        ? AF_INET : AF_INET6;
    my @ordered;
    while (@v4 || @v6) {
        if ($first_family == AF_INET) {
            push @ordered, shift @v4 if @v4;
            push @ordered, shift @v6 if @v6;
        } else {
            push @ordered, shift @v6 if @v6;
            push @ordered, shift @v4 if @v4;
        }
    }
    return [ @ordered, @other ];
}

sub _attempt_next ($self) {
    return if $self->{state} ne 'pending' || $self->{pending_result};

    while ($self->{candidate_at} < @{ $self->{candidates} }) {
        my $candidate = $self->{candidates}[ $self->{candidate_at}++ ];
        next if defined($self->{local_family})
            && $candidate->{family} != $self->{local_family};
        $self->{compatible_candidate_seen} = 1;
        my $fh;
        $self->{attempt_count}++;
        if (!socket(
            $fh,
            $candidate->{family},
            SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC,
            $candidate->{protocol},
        )) {
            $self->{last_errno} = 0 + $!;
            $self->{last_operation} = 'socket';
            next;
        }

        my $configured = eval {
            Linux::Event::_SocketConfig::apply_policy(
                $fh, $candidate->{family}, $self->{socket_policy},
            );
            Linux::Event::_SocketConfig::bind_device(
                $fh, $self->{bind_device},
            ) if defined $self->{bind_device};
            $self->{stream}->_configure_socket(
                $fh, 'connect',
                Linux::Event::Address->new($candidate->{sockaddr}),
            );
            if ($self->{local_bind}) {
                my $packed = defined($self->{local_family})
                    ? $self->{local_packed}
                    : $candidate->{family} == AF_INET
                        ? inet_pton(AF_INET, '0.0.0.0')
                        : inet_pton(AF_INET6, '::');
                my $sockaddr = $candidate->{family} == AF_INET
                    ? pack_sockaddr_in($self->{local_port}, $packed)
                    : pack_sockaddr_in6($self->{local_port}, $packed);
                if (!bind($fh, $sockaddr)) {
                    my $errno = 0 + $!;
                    local $! = $errno;
                    die Linux::Event::Error->new(
                        type      => 'socket_configuration',
                        operation => 'bind',
                        option    => defined($self->{local_host})
                            ? 'local_host' : 'local_port',
                        errno     => $errno,
                        message   => "$!",
                        host      => $self->{local_host},
                        port      => $self->{local_port},
                    );
                }
            }
            1;
        };
        if (!$configured) {
            my $failure = $@;
            close $fh;
            my $error = blessed($failure)
                && $failure->isa('Linux::Event::Error')
                ? $failure
                : Linux::Event::Error->new(
                    type      => 'socket_configuration',
                    operation => 'configure_socket',
                    message   => "$failure" || 'socket configuration failed',
                );
            $self->_queue_error($error);
            return;
        }

        my $id = $self->{next_attempt}++;
        my $attempt = {
            request => $self,
            id      => $id,
            fh      => $fh,
            watcher => undef,
        };
        $self->{attempts}{$id} = $attempt;

        if (connect($fh, $candidate->{sockaddr})) {
            $self->_queue_success($attempt);
            return;
        }

        my $errno = 0 + $!;
        if ($errno == Errno::EINPROGRESS()
            || $errno == Errno::EALREADY()
            || $errno == Errno::EWOULDBLOCK()) {
            my $watcher = eval {
                $self->{loop}->watch_fd(
                    fileno($fh),
                    _internal => 1,
                    fh    => $fh,
                    data  => $attempt,
                    write => \&_attempt_ready,
                    error => \&_attempt_ready,
                    _callback_data_arg => 1,
                );
            };
            if (!$watcher) {
                my $message = "$@" || 'could not register connection socket';
                $self->_close_attempt($attempt);
                $self->_queue_error($self->_error(
                    type => 'setup', operation => 'watch',
                    message => $message,
                ));
                return;
            }
            $attempt->{watcher} = $watcher;
            $self->{fallback_at} = _now() + 0.250
                if $self->{candidate_at} < @{ $self->{candidates} };
            $self->_rearm_timer;
            return;
        }

        $self->{last_errno} = $errno;
        $self->{last_operation} = 'connect';
        delete $self->{attempts}{$id};
        close $fh;
    }

    $self->{fallback_at} = undef;
    $self->_rearm_timer;
    return if keys %{ $self->{attempts} };

    if (defined($self->{local_family})
        && !$self->{compatible_candidate_seen}) {
        $self->_queue_error($self->_error(
            type      => 'socket_configuration',
            operation => 'bind',
            option    => 'local_host',
            message   => 'local_host address family does not match any peer address',
        ));
        return;
    }

    my $errno = $self->{last_errno} // Errno::EIO();
    my $operation = $self->{last_operation} // 'connect';
    my $type = $operation eq 'socket' ? 'socket' : 'connect';
    $self->_queue_error($self->_error(
        type      => $type,
        operation => $operation,
        errno     => $errno,
        message   => _system_message($errno),
    ));
    return;
}

sub _attempt_ready ($attempt) {
    my $self = $attempt->{request};
    return if !$self || $self->{state} ne 'pending';
    return if !exists $self->{attempts}{ $attempt->{id} };

    my $raw = getsockopt($attempt->{fh}, SOL_SOCKET, SO_ERROR);
    my $errno;
    if (!defined $raw) {
        $errno = 0 + $!;
    } elsif (length($raw) < 4) {
        $errno = Errno::EIO();
    } else {
        $errno = unpack('i', $raw);
    }

    if ($errno == 0) {
        $self->_finish_success($attempt);
        return;
    }
    $self->{last_errno} = $errno;
    $self->{last_operation} = 'connect';
    $self->_close_attempt($attempt);
    $self->_attempt_next;
    return;
}

sub _ensure_timer ($self) {
    return $self->{timer_fd} if defined $self->{timer_fd};
    my $fd = __PACKAGE__->_timerfd_new;
    my $watcher = eval {
        $self->{loop}->watch(
            fd   => $fd,
            _internal => 1,
            data => $self,
            read => \&_timer_ready,
            _callback_data_arg => 1,
        );
    };
    if (!$watcher) {
        my $failure = $@ || 'could not register connection timer';
        __PACKAGE__->_timerfd_close($fd);
        die $failure;
    }
    $self->{timer_fd} = $fd;
    $self->{timer_watcher} = $watcher;
    return $fd;
}

sub _rearm_timer ($self) {
    return if !$self->{loop} || $self->{state} ne 'pending';
    my $delay;
    if ($self->{pending_result}) {
        $delay = 0.000000001;
    } else {
        my @when = grep { defined } $self->{deadline_at}, $self->{fallback_at};
        if (@when) {
            my $next = $when[0];
            for my $when (@when[1 .. $#when]) {
                $next = $when if $when < $next;
            }
            $delay = $next - _now();
            $delay = 0.000000001 if $delay <= 0;
        }
    }
    if (defined $delay) {
        __PACKAGE__->_timerfd_arm($self->_ensure_timer, $delay);
    } elsif (defined $self->{timer_fd}) {
        __PACKAGE__->_timerfd_arm($self->{timer_fd}, 0);
    }
    return;
}

sub _queue_success ($self, $attempt) {
    return if ($self->{state} ne 'pending' && $self->{state} ne 'detached')
        || $self->{pending_result};
    $self->{pending_result} = [ success => $attempt ];
    return if !$self->{loop};
    $self->_rearm_timer;
    return;
}

sub _queue_error ($self, $error) {
    return if ($self->{state} ne 'pending' && $self->{state} ne 'detached')
        || $self->{pending_result};
    $self->{pending_result} = [ error => $error ];
    return if !$self->{loop};
    $self->_rearm_timer;
    return;
}

sub _timer_ready ($self) {
    return if $self->{state} ne 'pending';
    __PACKAGE__->_timerfd_consume($self->{timer_fd});
    if (my $result = delete $self->{pending_result}) {
        my ($kind, $value) = @$result;
        if ($kind eq 'success') {
            $self->_finish_success($value);
        } else {
            $self->_finish_error($value);
        }
        return;
    }

    my $now = _now();
    if (defined($self->{deadline_at}) && $now >= $self->{deadline_at}) {
        $self->_finish_error($self->_error(
            type      => 'timeout',
            operation => 'connect',
            errno     => Errno::ETIMEDOUT(),
            message   => 'connection deadline expired',
        ));
        return;
    }
    if (defined($self->{fallback_at}) && $now >= $self->{fallback_at}) {
        $self->{fallback_at} = undef;
        $self->_attempt_next;
        return;
    }
    $self->_rearm_timer;
    return;
}

sub _close_attempt ($self, $attempt, $keep_fh = 0) {
    return if !$attempt;
    delete $self->{attempts}{ $attempt->{id} };
    if (my $watcher = delete $attempt->{watcher}) {
        $watcher->cancel;
    }
    my $fh = delete $attempt->{fh};
    close $fh if $fh && !$keep_fh;
    $attempt->{request} = undef;
    return $fh;
}

sub _close_attempts ($self, $except = undef) {
    for my $attempt (values %{ $self->{attempts} }) {
        next if $except && refaddr($attempt) == refaddr($except);
        $self->_close_attempt($attempt);
    }
    return;
}

sub _close_timer ($self) {
    if (my $watcher = delete $self->{timer_watcher}) {
        $watcher->cancel;
    }
    if (defined(my $fd = delete $self->{timer_fd})) {
        __PACKAGE__->_timerfd_close($fd);
    }
    return;
}

sub _finish_success ($self, $attempt) {
    return if $self->{state} ne 'pending';
    return if !exists $self->{attempts}{ $attempt->{id} };

    $self->{state} = 'connected';
    $self->_cancel_resolution;
    $self->_close_attempts($attempt);
    $self->_close_timer;

    my $watcher = delete $attempt->{watcher};
    my $fh = delete $attempt->{fh};
    delete $self->{attempts}{ $attempt->{id} };
    $attempt->{request} = undef;

    my $stream = $self->{stream};
    my $ok = eval { $stream->_connect_succeeded($fh); 1 };
    my $callback_error = $@;

    # If the callback registered Stream or another watcher for this fd, the
    # old handle is already inactive and cancel() is harmless. Otherwise this
    # removes connection's now-unused writable registration.
    $watcher->cancel if $watcher;
    die $callback_error if !$ok;
    return;
}

sub _finish_error ($self, $error) {
    return if $self->{state} ne 'pending';
    $self->{state} = 'failed';
    $self->{error} = $error;
    $self->{pending_result} = undef;
    $self->_cancel_resolution;
    $self->_close_attempts;
    $self->_close_timer;
    $self->{stream}->_connect_failed($error);
    return;
}

1;
