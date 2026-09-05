package Linux::Event::_Socket::Listener;
use v5.36;
use strict;
use warnings;

use parent 'Linux::Event::_Socket';

use Carp qw(croak);
use Errno ();
use Fcntl qw(F_GETFD F_GETFL F_SETFD F_SETFL FD_CLOEXEC O_NONBLOCK);
use Scalar::Util qw(blessed);
use Socket qw(
    AF_INET AF_INET6 AF_UNIX AI_PASSIVE
    IPPROTO_IPV6 IPV6_V6ONLY
    SOCK_STREAM SOCK_NONBLOCK SOCK_CLOEXEC
    SOL_SOCKET SO_ACCEPTCONN SO_ERROR SO_REUSEADDR SO_REUSEPORT
    getaddrinfo pack_sockaddr_un
);

use Linux::Event::Error;
use Linux::Event::Address;
use Linux::Event::_Socket::Stream ();
use Linux::Event::_SocketConfig ();

require XSLoader;
XSLoader::load(__PACKAGE__);

my %CLASS_DESCRIPTOR;

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak "$class is not a Linux::Event::_Socket::Listener subclass"
        if !$class->isa(__PACKAGE__);

    my $accept_client = $class->can('_accept_client');
    my $on_accept = $class->can('on_accept');
    my $on_error = $class->can('on_error');
    croak "$class must define _accept_client()" if !$accept_client;
    croak "$class must define on_error()" if !$on_error;
    return $CLASS_DESCRIPTOR{$class} = {
        accept_client => $accept_client,
        on_accept     => $on_accept,
        on_error      => $on_error,
    };
}

sub _integer ($name, $value, $minimum, $maximum = 2_147_483_647) {
    croak "new(): $name must be an integer"
        if !defined($value) || ref($value) || $value !~ /\A\d+\z/;
    my $digits = "$value";
    $digits =~ s/\A0+(?=\d)//;
    croak "new(): $name must be at most $maximum"
        if length($digits) > length("$maximum")
        || (length($digits) == length("$maximum")
            && $digits gt "$maximum");
    $value = 0 + $value;
    croak "new(): $name must be at least $minimum" if $value < $minimum;
    return $value;
}

sub _boolean ($name, $value) {
    croak "new(): $name must be zero or one"
        if !defined($value) || ref($value) || $value !~ /\A[01]\z/;
    return $value ? 1 : 0;
}

sub _message ($errno) {
    local $! = $errno;
    return "$!";
}

sub _family_name ($family) {
    return 'inet' if $family == AF_INET;
    return 'inet6' if $family == AF_INET6;
    return 'unix' if $family == AF_UNIX;
    return 'unknown';
}

sub _setup_error (%arg) {
    die Linux::Event::Error->new(
        type      => 'setup',
        fatal     => 1,
        %arg,
    );
}

sub _set_adopted_flags ($fh) {
    my $status = fcntl($fh, F_GETFL, 0);
    _setup_error(
        operation => 'fcntl', errno => 0 + $!, message => _message(0 + $!),
    ) if !defined $status;
    fcntl($fh, F_SETFL, $status | O_NONBLOCK) or _setup_error(
        operation => 'fcntl', errno => 0 + $!, message => _message(0 + $!),
    );

    my $fd_status = fcntl($fh, F_GETFD, 0);
    _setup_error(
        operation => 'fcntl', errno => 0 + $!, message => _message(0 + $!),
    ) if !defined $fd_status;
    fcntl($fh, F_SETFD, $fd_status | FD_CLOEXEC) or _setup_error(
        operation => 'fcntl', errno => 0 + $!, message => _message(0 + $!),
    );
    return;
}

sub _create_inet_listener ($host, $port, $backlog, $reuseaddr, $reuseport,
    $v6only, $bind_device) {
    my $node = $host eq '*' ? undef : $host;
    my ($resolver_error, @result) = getaddrinfo(
        $node, $port, { socktype => SOCK_STREAM, flags => AI_PASSIVE },
    );
    _setup_error(
        operation => 'resolve',
        message   => "$resolver_error",
        host      => $host,
        port      => $port,
    ) if $resolver_error;

    my ($last_errno, $last_operation);
    my $compatible = 0;
    for my $candidate (@result) {
        next if !defined($candidate->{family}) || !defined($candidate->{addr});
        next if $candidate->{family} != AF_INET
            && $candidate->{family} != AF_INET6;
        next if defined($v6only) && $candidate->{family} != AF_INET6;
        $compatible = 1;
        my $fh;
        if (!socket(
            $fh,
            $candidate->{family},
            SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC,
            $candidate->{protocol} // 0,
        )) {
            ($last_errno, $last_operation) = (0 + $!, 'socket');
            next;
        }
        if ($reuseaddr
            && !setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack('i', 1))) {
            ($last_errno, $last_operation) = (0 + $!, 'setsockopt');
            close $fh;
            next;
        }
        if ($reuseport
            && !setsockopt($fh, SOL_SOCKET, SO_REUSEPORT, pack('i', 1))) {
            ($last_errno, $last_operation) = (0 + $!, 'setsockopt');
            close $fh;
            next;
        }
        if (defined($v6only) && $candidate->{family} == AF_INET6
            && !setsockopt(
                $fh, IPPROTO_IPV6, IPV6_V6ONLY, pack('i', $v6only ? 1 : 0),
            )) {
            ($last_errno, $last_operation) = (0 + $!, 'setsockopt');
            close $fh;
            next;
        }
        if (defined $bind_device) {
            my $ok = eval {
                Linux::Event::_SocketConfig::bind_device($fh, $bind_device);
                1;
            };
            if (!$ok) {
                my $error = $@;
                close $fh;
                die $error;
            }
        }
        if (!bind($fh, $candidate->{addr})) {
            ($last_errno, $last_operation) = (0 + $!, 'bind');
            close $fh;
            next;
        }
        if (!listen($fh, $backlog)) {
            ($last_errno, $last_operation) = (0 + $!, 'listen');
            close $fh;
            next;
        }
        return ($fh, $candidate->{family});
    }

    die Linux::Event::Error->new(
        type      => 'socket_configuration',
        operation => 'setsockopt',
        option    => 'v6only',
        message   => 'v6only requires an IPv6 bind address',
        host      => $host,
        port      => $port,
    ) if defined($v6only) && !$compatible;

    $last_errno //= Errno::EADDRNOTAVAIL();
    $last_operation //= 'bind';
    _setup_error(
        operation => $last_operation,
        errno     => $last_errno,
        message   => _message($last_errno),
        host      => $host,
        port      => $port,
    );
}

sub _create_unix_listener ($path, $backlog, $unlink_existing, $permissions) {
    if (-e $path || -l $path) {
        croak "new(): Unix path already exists: $path" if !$unlink_existing;
        croak "new(): refusing to unlink non-socket path: $path" if !-S $path;
        unlink($path) or _setup_error(
            operation => 'unlink',
            errno     => 0 + $!,
            message   => _message(0 + $!),
            path      => $path,
        );
    }

    socket(my $fh, AF_UNIX,
        SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0) or _setup_error(
        operation => 'socket',
        errno     => 0 + $!,
        message   => _message(0 + $!),
        path      => $path,
    );
    if (!bind($fh, pack_sockaddr_un($path))) {
        my $errno = 0 + $!;
        close $fh;
        _setup_error(
            operation => 'bind', errno => $errno, message => _message($errno),
            path => $path,
        );
    }
    if (defined($permissions) && !chmod($permissions, $path)) {
        my $errno = 0 + $!;
        close $fh;
        unlink $path;
        _setup_error(
            operation => 'chmod', errno => $errno,
            message => _message($errno), path => $path,
        );
    }
    if (!listen($fh, $backlog)) {
        my $errno = 0 + $!;
        close $fh;
        unlink $path;
        _setup_error(
            operation => 'listen', errno => $errno,
            message => _message($errno), path => $path,
        );
    }
    return ($fh, AF_UNIX);
}

sub new ($class, %opt) {
    croak 'new(): must be called as a class method' if ref $class;
    my $loop = delete $opt{loop};
    croak 'new(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $stream_class = delete $opt{stream_class}
        // croak 'new(): missing stream_class';
    croak 'new(): stream_class must name a Linux::Event::_Socket::Stream subclass'
        if ref($stream_class) || !$stream_class->isa('Linux::Event::_Socket::Stream');
    $stream_class->_validate_accepted_configuration;

    my $descriptor = _descriptor_for($class);
    my %known = map { $_ => 1 } qw(
        loop data backlog max_accept_per_tick edge_triggered
        reuseaddr reuseport v6only unlink unlink_on_close permissions
        fh owns_socket host port unix bind_device
    );
    my @unknown = sort grep { !$known{$_} } keys %opt;
    croak 'new(): unknown options: ' . join(', ', @unknown) if @unknown;
    my %supplied = map { $_ => exists $opt{$_} } keys %opt;
    my $data = delete $opt{data};
    my $backlog = _integer('backlog', delete($opt{backlog}) // 4096, 1);
    my $maximum = _integer(
        'max_accept_per_tick', delete($opt{max_accept_per_tick}) // 256, 0,
    );
    my $edge = _boolean(
        'edge_triggered', delete($opt{edge_triggered}) // 0,
    );
    croak 'new(): edge_triggered requires max_accept_per_tick => 0'
        if $edge && $maximum;
    my $reuseaddr = _boolean(
        'reuseaddr', exists($opt{reuseaddr}) ? delete($opt{reuseaddr}) : 1,
    );
    my $reuseport = _boolean('reuseport', delete($opt{reuseport}) // 0);
    my $v6only = delete $opt{v6only};
    $v6only = _boolean('v6only', $v6only) if defined $v6only;
    my $unlink_existing = _boolean('unlink', delete($opt{unlink}) // 0);
    my $unlink_on_close = exists($opt{unlink_on_close})
        ? _boolean('unlink_on_close', delete($opt{unlink_on_close})) : 1;
    my $permissions = delete $opt{permissions};
    $permissions = _integer('permissions', $permissions, 0, 07777)
        if defined $permissions;
    my $bind_device = delete $opt{bind_device};
    croak 'new(): bind_device must be a non-empty interface name'
        if defined($bind_device)
        && (ref($bind_device) || $bind_device eq '' || $bind_device =~ /\0/);

    my $fh_mode = exists $opt{fh};
    my $host_mode = exists($opt{host}) || exists($opt{port});
    my $unix_mode = exists $opt{unix};
    my $mode_count = ($fh_mode ? 1 : 0) + ($host_mode ? 1 : 0)
        + ($unix_mode ? 1 : 0);
    croak 'new(): exactly one socket source is required '
        . '(fh, host/port, or unix)' if $mode_count != 1;

    my @inapplicable;
    if ($fh_mode) {
        @inapplicable = grep { $supplied{$_} }
            qw(backlog reuseaddr reuseport v6only unlink unlink_on_close
               permissions);
    } elsif ($host_mode) {
        @inapplicable = grep { $supplied{$_} }
            qw(owns_socket unlink unlink_on_close permissions);
    } else {
        @inapplicable = grep { $supplied{$_} }
            qw(owns_socket reuseaddr reuseport v6only bind_device);
    }
    croak 'new(): options not valid for this socket source: '
        . join(', ', @inapplicable) if @inapplicable;

    my ($fh, $host, $port, $path, $family, $owns_socket);
    if ($fh_mode) {
        $fh = delete $opt{fh};
        croak 'new(): fh must be a filehandle'
            if !defined($fh) || !defined(fileno($fh));
        my $accepting = getsockopt($fh, SOL_SOCKET, SO_ACCEPTCONN);
        croak 'new(): fh is not a listening socket'
            if !defined($accepting) || !unpack('i', $accepting);
        $owns_socket = _boolean(
            'owns_socket', delete($opt{owns_socket}) // 0,
        );
        my $local = Linux::Event::Address->new(getsockname($fh));
        $family = $local->family_number;
        croak 'new(): fh must use an IPv4, IPv6, or Unix address family'
            if !defined($family) || ($family != AF_INET
                && $family != AF_INET6 && $family != AF_UNIX);
        croak 'new(): bind_device is valid only for TCP listeners'
            if defined($bind_device)
            && $family != AF_INET && $family != AF_INET6;
        _set_adopted_flags($fh);
        Linux::Event::_SocketConfig::bind_device($fh, $bind_device)
            if defined $bind_device;
        $host = $local->host;
        $port = $local->port;
    } elsif ($host_mode) {
        $host = delete $opt{host};
        $port = delete $opt{port};
        croak 'new(): host is required' if !defined $host;
        croak 'new(): host must be a non-empty string without NUL bytes'
            if ref($host) || $host eq '' || $host =~ /\0/;
        $port = _integer('port', $port, 0, 65535);
        ($fh, $family) = _create_inet_listener(
            $host, $port, $backlog, $reuseaddr, $reuseport, $v6only,
            $bind_device,
        );
        my $local = Linux::Event::Address->new(getsockname($fh));
        $host = $local->host;
        $port = $local->port;
        $owns_socket = 1;
    } else {
        $path = delete $opt{unix};
        croak 'new(): unix must be a non-empty path without NUL bytes'
            if !defined($path) || ref($path) || $path eq '' || $path =~ /\0/;
        ($fh, $family) = _create_unix_listener(
            $path, $backlog, $unlink_existing, $permissions,
        );
        $owns_socket = 1;
    }
    croak 'new(): unknown options: ' . join(', ', sort keys %opt) if %opt;

    my $self = bless {
        descriptor          => $descriptor,
        stream_class        => $stream_class,
        loop                => undef,
        data                => $data,
        fh                  => $fh,
        family              => _family_name($family),
        family_number       => $family,
        host                => $host,
        port                => $port,
        unix                => $path,
        backlog             => $backlog,
        max_accept_per_tick => $maximum,
        edge_triggered      => $edge,
        owns_socket         => $owns_socket ? 1 : 0,
        unlink_on_close     => (defined($path) && $unlink_on_close) ? 1 : 0,
        state               => 'unattached',
        watcher             => undef,
        accepted            => 0,
        last_error          => undef,
    }, $class;

    $self->_attach_to_loop($loop) if $loop;
    return $self;
}

sub stream_class ($self) { $self->{stream_class} }

sub _accept_client ($self, $fh, $peer) {
    my $class = $self->{stream_class};
    my $stream;
    my $prepared = eval {
        $stream = $class->new(
            fh        => $fh,
            peer      => $peer,
            data      => $self->data,
            _accepted => 1,
        );
        $stream->_attach_to_loop($self->loop);
        1;
    };
    if (!$prepared) {
        my $failure = $@;
        eval { $stream->close; 1 } if $stream;
        CORE::close($fh) if !$stream && defined fileno($fh);
        my $error = blessed($failure)
            && $failure->isa('Linux::Event::Error')
            ? $failure
            : Linux::Event::Error->new(
                type      => 'setup',
                operation => 'accepted_socket',
                message   => "$failure" || 'accepted Socket setup failed',
                fatal     => 0,
                host      => $self->host,
                port      => $self->port,
                family    => $self->family,
            );
        $self->{last_error} = $error;
        $self->{descriptor}{on_error}->($self, $error);
        return;
    }
    if (my $callback = $self->{descriptor}{on_accept}) {
        my $ok = eval { $callback->($self, $stream); 1 };
        if (!$ok) {
            my $message = "$@";
            $message =~ s/\s+\z//;
            $message = 'on_accept callback failed' if $message eq '';
            eval { $stream->close; 1 };
            my $error = Linux::Event::Error->new(
                type      => 'callback',
                operation => 'on_accept',
                message   => $message,
                fatal     => 0,
                host      => $self->host,
                port      => $self->port,
                path      => $self->path,
                family    => $self->family,
            );
            $self->{last_error} = $error;
            $self->{descriptor}{on_error}->($self, $error);
            return;
        }
    }
    $stream->_fire_ready if !$stream->transport;
    return;
}

sub on_error ($self, $error) {
    die "listener failed: $error\n";
}

sub CLONE_SKIP ($class) { 1 }

sub _attach_to_loop ($self, $loop) {
    croak 'add(): Listener is not unattached'
        if $self->{state} ne 'unattached' || $self->{loop};
    my $watcher = eval {
        $loop->watch(
            fh   => $self->{fh},
            _internal => 1,
            data => $self,
            read => \&_accept_ready,
            error => \&_listener_error_ready,
            edge_triggered => $self->{edge_triggered} ? 1 : 0,
            _callback_data_arg => 1,
        );
    };
    if (!$watcher) {
        my $failure = $@ || 'could not register Listener socket';
        die $failure if blessed($failure)
            && $failure->isa('Linux::Event::Error');
        die Linux::Event::Error->new(
            type      => 'setup',
            operation => 'watch',
            fatal     => 0,
            message   => "$failure",
            host      => $self->{host},
            port      => $self->{port},
            path      => $self->{unix},
            family    => $self->{family},
        );
    }
    $self->{loop} = $loop;
    $self->{watcher} = $watcher;
    $self->{state} = 'listening';
    return $self;
}

sub loop        ($self) { $self->{loop} }
sub fh          ($self) { $self->{fh} }
sub fd          ($self) { defined($self->{fh}) ? fileno($self->{fh}) : undef }
sub host        ($self) { $self->{host} }
sub port        ($self) { $self->{port} }
sub path        ($self) { $self->{unix} }
sub family      ($self) { $self->{family} }
sub family_number ($self) { $self->{family_number} }
sub is_tcp      ($self) {
    return $self->{family} eq 'inet' || $self->{family} eq 'inet6';
}
sub is_unix     ($self) { return $self->{family} eq 'unix' }
sub state       ($self) { $self->{state} }
sub accepted    ($self) { $self->{accepted} }
sub last_error  ($self) { $self->{last_error} }
sub is_paused   ($self) { $self->{state} eq 'paused' }
sub is_running  ($self) {
    return $self->{state} eq 'listening' || $self->{state} eq 'paused';
}
sub is_terminal ($self) {
    return $self->{state} eq 'closed' || $self->{state} eq 'failed'
        || $self->{state} eq 'detached';
}

sub data ($self, @arg) {
    $self->{data} = $arg[0] if @arg;
    return $self->{data};
}

sub pause ($self) {
    return $self if $self->{state} ne 'listening';
    $self->{watcher}->disable_read if $self->{watcher};
    $self->{state} = 'paused';
    return $self;
}

sub resume ($self) {
    return $self if $self->{state} ne 'paused';
    $self->{watcher}->enable_read if $self->{watcher};
    $self->{state} = 'listening';
    return $self;
}

sub _close_batch_tail ($batch, $at) {
    while ($at < @$batch) {
        my $fd = $batch->[$at];
        __PACKAGE__->_close_fd($fd);
        $at += 2;
    }
    return;
}

sub _accept_ready ($self) {
    return if $self->{state} ne 'listening';
    my $batch = __PACKAGE__->_accept4_batch(
        fileno($self->{fh}), $self->{max_accept_per_tick},
    );
    my $errno = $batch->[0];
    my $at = 1;
    while ($at < @$batch) {
        my $fd = $batch->[$at++];
        my $sockaddr = $batch->[$at++];
        if ($self->{state} ne 'listening') {
            __PACKAGE__->_close_fd($fd);
            _close_batch_tail($batch, $at);
            return;
        }

        open(my $client, '+<&=', $fd) or do {
            my $open_errno = 0 + $!;
            __PACKAGE__->_close_fd($fd);
            _close_batch_tail($batch, $at);
            die "failed to create accepted filehandle: "
                . _message($open_errno);
        };
        my $peer = Linux::Event::Address->new($sockaddr);
        $self->{accepted}++;
        my $callback = $self->{descriptor}{accept_client};
        my $ok = eval { $callback->($self, $client, $peer); 1 };
        my $callback_error = $@;
        if (!$ok) {
            close $client;
            _close_batch_tail($batch, $at);
            die $callback_error;
        }
    }

    $self->_accept_error($errno) if $errno && $self->{state} eq 'listening';
    return;
}

sub _accept_error ($self, $errno) {
    my $resource = $errno == Errno::EMFILE() || $errno == Errno::ENFILE()
        || $errno == Errno::ENOBUFS() || $errno == Errno::ENOMEM();
    my $error = Linux::Event::Error->new(
        type      => $resource ? 'resource' : 'accept',
        operation => 'accept',
        errno     => $errno,
        message   => _message($errno),
        fatal     => 0,
        host      => $self->{host},
        port      => $self->{port},
        path      => $self->{unix},
    );
    $self->{last_error} = $error;
    $self->pause if $resource;
    $self->{descriptor}{on_error}->($self, $error);
    return;
}

sub _listener_error_ready ($self) {
    return if !$self->is_running;
    my $raw = getsockopt($self->{fh}, SOL_SOCKET, SO_ERROR);
    my $errno = defined($raw) && length($raw) >= 4 ? unpack('i', $raw) : 0 + $!;
    my $error = Linux::Event::Error->new(
        type      => 'listener',
        operation => 'watch',
        errno     => $errno || undef,
        message   => $errno ? _message($errno) : 'listener socket closed',
        fatal     => 1,
        host      => $self->{host},
        port      => $self->{port},
        path      => $self->{unix},
    );
    $self->{last_error} = $error;
    $self->_shutdown('failed', 1);
    my $reported = eval {
        $self->{descriptor}{on_error}->($self, $error);
        1;
    };
    my $failure = $@;
    $self->{loop} = undef;
    die $failure if !$reported;
    return;
}

sub _shutdown ($self, $state, $retain_loop = 0) {
    return if $self->is_terminal;
    $self->{state} = $state;
    if (my $watcher = delete $self->{watcher}) {
        $watcher->cancel;
    }
    if (defined(my $fh = delete $self->{fh})) {
        close $fh if $self->{owns_socket};
    }
    if (defined($self->{unix}) && $self->{unlink_on_close}) {
        unlink $self->{unix} if -S $self->{unix};
    }
    $self->{loop} = undef if !$retain_loop;
    return;
}

sub close ($self) {
    $self->_shutdown('closed');
    return $self;
}

sub detach ($self) {
    return undef if $self->is_terminal;
    my $fh = $self->{fh};
    $self->{owns_socket} = 0;
    $self->{unlink_on_close} = 0;
    $self->_shutdown('detached');
    $self->{fh} = undef;
    return $fh;
}

sub DESTROY ($self) {
    eval { $self->close };
    return;
}

1;
