package Linux::Event::Stream;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.103';

use Carp qw(croak);
use Fcntl qw(F_GETFD F_GETFL F_SETFD F_SETFL FD_CLOEXEC O_NONBLOCK);
use mro ();
use POSIX qw(isfinite);
use Scalar::Util qw(looks_like_number weaken);
use Socket qw(SOL_SOCKET SO_ERROR);
use utf8 ();

use Linux::Event::Stream::_Connection ();
use Linux::Event::Error;
use Linux::Event::Address;
use Linux::Event::_SocketConfig ();

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my %FRAMER_DEFINITION;
my %TLS_DEFINITION;
my %CLASS_DESCRIPTOR;

sub _declare_framer ($base, $target, $definition) {
    croak 'a framer may be declared only for a Linux::Event::Stream subclass'
        if $target eq $base || !$target->isa($base);
    croak "$target already has a Stream descriptor"
        if exists $CLASS_DESCRIPTOR{$target};
    croak "$target already declares a framer"
        if exists $FRAMER_DEFINITION{$target};
    $FRAMER_DEFINITION{$target} = $definition;
    return;
}

sub _framer_for ($class) {
    for my $package (@{ mro::get_linear_isa($class) }) {
        return $FRAMER_DEFINITION{$package}
            if exists $FRAMER_DEFINITION{$package};
    }
    return undef;
}

sub _declare_tls ($base, $target, $definition) {
    croak 'TLS may be declared only for a Linux::Event::Stream subclass'
        if $target eq $base || !$target->isa($base);
    croak "$target already has a Stream descriptor"
        if exists $CLASS_DESCRIPTOR{$target};
    croak "$target already declares TLS"
        if exists $TLS_DEFINITION{$target};
    croak 'TLS declaration must be a hash reference'
        if ref($definition) ne 'HASH';
    $TLS_DEFINITION{$target} = $definition;
    return;
}

sub _tls_for ($class) {
    for my $package (@{ mro::get_linear_isa($class) }) {
        return $TLS_DEFINITION{$package}
            if exists $TLS_DEFINITION{$package};
    }
    return undef;
}

sub _stream_options_for ($class) {
    my %option = (
        high_watermark   => 1_048_576,
        low_watermark    =>   262_144,
        max_pending_bytes =>         0,
        read_size        =>    65_536,
        max_buffer       => 8_388_608,
        idle_timeout     =>         0,
        read_timeout     =>         0,
        write_timeout    =>         0,
        map { $_ => undef } Linux::Event::_SocketConfig::names(),
    );

    if (my $configure = $class->can('stream_options')) {
        my @configured = $configure->($class);
        my %configured;
        if (@configured == 1 && ref($configured[0]) eq 'HASH') {
            %configured = %{ $configured[0] };
        } else {
            croak "$class stream_options() returned an odd option list"
                if @configured % 2;
            %configured = @configured;
        }
        my @unknown = grep { !exists $option{$_} } keys %configured;
        croak "$class stream_options() returned unknown options: "
            . join(', ', sort @unknown) if @unknown;
        @option{keys %configured} = values %configured;
    }

    croak "$class high_watermark must be a non-negative integer"
        if $option{high_watermark} !~ /\A\d+\z/;
    croak "$class low_watermark must be a non-negative integer"
        if $option{low_watermark} !~ /\A\d+\z/;
    croak "$class low_watermark must be <= high_watermark"
        if $option{low_watermark} > $option{high_watermark};
    croak "$class max_pending_bytes must be a non-negative integer"
        if $option{max_pending_bytes} !~ /\A\d+\z/;
    croak "$class read_size must be a positive integer"
        if $option{read_size} !~ /\A\d+\z/ || $option{read_size} <= 0;
    croak "$class max_buffer must be a positive integer"
        if $option{max_buffer} !~ /\A\d+\z/ || $option{max_buffer} <= 0;
    for my $name (qw(idle_timeout read_timeout write_timeout)) {
        $option{$name} = _timeout_value($class, $name, $option{$name});
    }
    for my $name (Linux::Event::_SocketConfig::names()) {
        $option{$name} = Linux::Event::_SocketConfig::normalize(
            $class, $name, $option{$name},
        ) if defined $option{$name};
        delete $option{$name} if !defined $option{$name};
    }

    return \%option;
}

sub _timeout_value ($target, $name, $value) {
    my $seconds = !defined($value) || ref($value) || !looks_like_number($value)
        ? undef : 0 + $value;
    croak "$target $name must be a non-negative number of seconds"
        if !defined($seconds) || !isfinite($seconds) || $seconds < 0;
    croak "$target $name exceeds the supported timer range"
        if $seconds > 2_147_483_647;
    return $seconds;
}

sub _deadline_spec ($method, $value) {
    croak "$method(): deadline must be a hash reference"
        if ref($value) ne 'HASH';
    my %option = %$value;
    my $has_after = exists $option{after};
    my $has_at = exists $option{at};
    croak "$method(): deadline requires exactly one of after or at"
        if $has_after == $has_at;
    my $operation = delete $option{operation};
    croak "$method(): deadline operation must be a non-empty string"
        if !defined($operation) || ref($operation) || $operation eq '';
    my $name = $has_after ? 'after' : 'at';
    my $seconds = _timeout_value("$method(): deadline", $name,
        delete $option{$name});
    croak "$method(): unknown deadline options: "
        . join(', ', sort keys %option) if %option;
    return {
        absolute  => $has_at ? 1 : 0,
        seconds   => $seconds,
        operation => "$operation",
    };
}

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Stream is a base class; construct a Stream subclass'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Stream subclass"
        if !$class->isa(__PACKAGE__);

    my $framer = _framer_for($class);
    my $tls = _tls_for($class);
    my %callback = map { $_ => scalar $class->can($_) }
        qw(on_data on_message on_drain on_eof on_error on_close
           on_ready on_transport_ready configure_socket);

    if ($framer) {
        croak "$class declares a framer but does not define on_message()"
            if !$callback{on_message};
        croak "$class cannot define on_data() when it declares a framer"
            if $callback{on_data};
    } else {
        croak "$class has no framer and must define on_data()"
            if !$callback{on_data};
        croak "$class defines on_message() but does not declare a framer"
            if $callback{on_message};
    }

    my $option = _stream_options_for($class);
    my $native = $framer ? { %{ $framer->{native} } } : { read_mode => 0 };

    my $xs = Linux::Event::Stream::XSDescriptor->new(
        $option->{read_size},
        $option->{high_watermark},
        $option->{low_watermark},
        $option->{max_pending_bytes},
        $option->{max_buffer},
        $native->{read_mode},
        $callback{on_data},
        $callback{on_message},
        $callback{on_drain} ? \&_xs_drain : undef,
        \&_xs_read_eof,
        \&_xs_read_error,
        \&_xs_write_error,
        \&_xs_output_limit,
        \&_xs_write_empty,
        \&_xs_framing_error,
        $native->{delimiter},
        $native->{include_delimiter} // 0,
        $native->{max_frame},
        $native->{fixed_size} // 0,
        $native->{prefix_bytes} // 0,
        $native->{prefix_little} // 0,
        $native->{include_prefix} // 0,
    );

    my $descriptor = {
        class     => $class,
        xs        => $xs,
        options   => $option,
        native    => $native,
        framer    => $framer,
        tls       => $tls,
        callbacks => \%callback,
    };
    $CLASS_DESCRIPTOR{$class} = $descriptor;
    return $descriptor;
}

sub _xs_framing_error ($self, $message) {
    $self->_fail_framing($message);
    return;
}

sub _xs_read_eof ($self) {
    $self->_mark_eof;
    return;
}

sub _xs_read_error ($self, $errno) {
    local $! = $errno;
    $self->_fail_io('read', $errno);
    return;
}

sub _xs_write_error ($self, $errno) {
    local $! = $errno;
    $self->_fail_io('write', $errno);
    return;
}

sub _xs_output_limit ($self, $pending_bytes, $limit) {
    my $error = Linux::Event::Error->new(
        type          => 'output_limit',
        operation     => 'write',
        message       => "pending output would exceed $limit bytes",
        pending_bytes => $pending_bytes,
        limit         => $limit,
    );
    $self->_fail($error);
    return;
}

sub _xs_write_empty ($self) {
    return if $self->{closed};
    $self->{deadline_write_started} = undef;
    $self->_rearm_stream_deadline if $self->{deadline_started};
    $self->{watcher}->disable_write if $self->{watcher};
    $self->_finish_write_side if $self->{write_ending} && !$self->{write_ended};
    return;
}

sub _xs_drain ($self) {
    return if $self->{closed};
    if ($self->{preconnect_write_blocked}
        && !($self->{transport_ready_fired} & 0x02)) {
        $self->{preconnect_drain_reached} = 1;
        return;
    }
    delete $self->{preconnect_write_blocked};
    delete $self->{preconnect_drain_reached};
    my $callback = $self->{descriptor}{callbacks}{on_drain};
    $callback->($self) if $callback;
    return;
}

sub _xs_transport_event ($self, $status, $operation, $message) {
    return if $self->{closed};

    if ($status == 2) {
        $self->{watcher}->enable_read if $self->{watcher};
        return;
    }
    if ($status == 3) {
        $self->{watcher}->enable_write if $self->{watcher};
        return;
    }
    if ($status == 5) {
        my $error = Linux::Event::Error->new(
            type      => $self->transport_name // 'transport',
            operation => $operation,
            message   => $message || 'transport error',
        );
        $self->_fail($error);
        return;
    }

    if ($self->{xs_state} && $self->{xs_state}->transport_ready
        && !($self->{transport_ready_fired} & 0x01)) {
        $self->{transport_ready_fired} |= 0x01;
        $self->_start_stream_deadlines;
        if ($self->{transport}
            && $self->{transport}->can('_stream_transport_ready')) {
            $self->{transport}->_stream_transport_ready($self);
        }
        if ($self->{read_paused} && $self->{watcher}) {
            $self->{watcher}->disable_read;
        }
        if (my $callback = $self->{descriptor}{callbacks}{on_transport_ready}) {
            $callback->($self);
        }
        $self->_fire_ready;
    }
    if (($status == 0 || $status == 1) && $self->{write_ending}
        && !$self->pending_bytes) {
        $self->_finish_write_side;
        return if $self->{closed};
    }
    if ($self->{watcher} && !$self->pending_bytes
        && !$self->{write_ending}) {
        $self->{watcher}->disable_write;
    }
    return;
}

sub _watch_error_xs_cb ($state) {
    my $self = $state->stream or return;
    $self->_on_terminal_ready;
}

sub new ($class, %opt) {
    croak 'new(): must be called as a class method' if ref $class;
    my $loop = delete $opt{loop};
    croak 'new(): loop must be an object implementing add() and watch_fd()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch_fd'));
    my $fh = delete $opt{fh};
    my $connect = delete $opt{_connect};
    my $accepted = delete($opt{_accepted}) // 0;
    my $tls_role = delete $opt{tls_role};
    my $data = delete $opt{data};
    my $peer = delete $opt{peer};
    my $transport = delete $opt{transport};
    my $socket_override = Linux::Event::_SocketConfig::extract('new', \%opt);
    my %timeout_override;
    for my $name (qw(idle_timeout read_timeout write_timeout)) {
        $timeout_override{$name} = _timeout_value('new():', $name,
            delete $opt{$name}) if exists $opt{$name};
    }
    my $initial_deadline = exists($opt{deadline})
        ? _deadline_spec('new', delete $opt{deadline}) : undef;
    croak 'new(): unknown options: ' . join(', ', sort keys %opt) if %opt;
    croak 'new(): exactly one of fh or an outbound connection is required'
        if defined($fh) == defined($connect);
    croak 'new(): fh must be a filehandle'
        if defined($fh) && !defined(fileno($fh));
    croak 'new(): internal connection options must be a hash reference'
        if defined($connect) && ref($connect) ne 'HASH';
    croak 'new(): tls_role must be client or server'
        if defined($tls_role)
        && (ref($tls_role) || ($tls_role ne 'client' && $tls_role ne 'server'));
    croak 'new(): tls_role is only valid with fh'
        if defined($tls_role) && !defined($fh);
    croak 'new(): internal accepted mode is only valid with fh'
        if $accepted && !defined($fh);
    croak 'new(): tls_role cannot be combined with accepted mode'
        if $accepted && defined($tls_role);
    croak 'new(): transport must be an object implementing _stream_transport_bind()'
        if defined($transport)
        && (!ref($transport) || !$transport->can('_stream_transport_bind'));

    my $descriptor = _descriptor_for($class);
    my %socket_policy = map {
        $_ => exists($socket_override->{$_})
            ? $socket_override->{$_} : $descriptor->{options}{$_}
    } Linux::Event::_SocketConfig::names();
    if (my $tls = $descriptor->{tls}) {
        croak 'new(): transport cannot be supplied for a TLS-declared Stream'
            if defined $transport;
        require Linux::Event::TLS;
        my $role = defined($connect) ? 'client'
            : $accepted ? 'server'
            : $tls_role;
        croak 'new(): a TLS-declared adopted fh requires tls_role'
            if !defined $role;
        $transport = $role eq 'server'
            ? Linux::Event::TLS->_server_from_declaration($tls)
            : Linux::Event::TLS->_client_from_declaration(
                $tls, defined($connect) ? $connect->{host} : undef,
            );
    } elsif (defined $tls_role) {
        croak 'new(): tls_role requires a Stream subclass declaring TLS';
    }
    my %timeout = map {
        $_ => exists($timeout_override{$_})
            ? $timeout_override{$_} : $descriptor->{options}{$_}
    } qw(idle_timeout read_timeout write_timeout);
    my $self = bless {
        descriptor  => $descriptor,
        loop        => undef,
        fh          => $fh,
        watcher     => undef,
        data        => $data,
        transport   => $transport,
        xs_state    => undef,
        read_paused => 0,
        read_eof    => 0,
        write_ending => 0,
        write_ended  => 0,
        closed       => 0,
        detached     => 0,
        close_fired  => 0,
        last_error   => undef,
        transport_ready_fired => 0,
        transport_deadline_watcher => undef,
        transport_shutdown_started => 0,
        timeout => \%timeout,
        timeout_override => \%timeout_override,
        initial_deadline => $initial_deadline,
        operation_deadline_at => undef,
        operation_deadline_name => undef,
        operation_deadline_timeout => undef,
        deadline_timer => undef,
        deadline_started => 0,
        deadline_tracking => 0,
        deadline_read_started => undef,
        deadline_write_started => undef,
        socket_policy => \%socket_policy,
        local         => undef,
    }, $class;
    $self->{peer} = $peer if defined $peer;

    if (defined $fh) {
        my $configured = eval {
            my $local = Linux::Event::Address->new(getsockname($fh));
            my $family = $local->family_number;
            Linux::Event::_SocketConfig::apply_policy(
                $fh, $family, $self->{socket_policy},
            );
            my $role = $accepted ? 'accepted' : 'adopted';
            my $address = $peer;
            if (!defined($address)) {
                my $packed = eval { getpeername($fh) };
                $address = Linux::Event::Address->new($packed)
                    if defined $packed;
                $self->{peer} = $address if defined $address;
            }
            $self->_configure_socket($fh, $role, $address);
            $self->{local} = $local;
            1;
        };
        if (!$configured) {
            my $error = $@ || 'socket configuration failed';
            close $fh;
            $self->{fh} = undef;
            die $error;
        }
        $self->_prepare_fh($fh);
    }
    if ($connect) {
        $self->{preconnect_output} = [];
        $self->{preconnect_bytes} = 0;
        $self->{connection} = Linux::Event::Stream::_Connection->new(
            %$connect,
            stream => $self,
            socket_policy => $self->{socket_policy},
        );
    }
    $self->_attach_to_loop($loop) if $loop;
    return $self;
}

sub connect ($class, %opt) {
    croak 'connect(): must be called as a class method' if ref $class;
    my %stream;
    for my $name (qw(loop data transport idle_timeout read_timeout
        write_timeout deadline tcp_nodelay keepalive keepalive_idle
        keepalive_interval keepalive_count tcp_user_timeout send_buffer
        receive_buffer)) {
        $stream{$name} = delete $opt{$name} if exists $opt{$name};
    }
    return $class->new(%stream, _connect => \%opt);
}

sub CLONE ($class) {
    %CLASS_DESCRIPTOR = ();
    return;
}

sub CLONE_SKIP ($class) { 1 }

sub _validate_accepted_configuration ($class) {
    my $descriptor = _descriptor_for($class);
    if (my $tls = $descriptor->{tls}) {
        require Linux::Event::TLS;
        Linux::Event::TLS->_server_from_declaration($tls);
    }
    return;
}

sub _prepare_fh ($self, $fh) {
    _set_nonblocking($fh);
    my $descriptor = $self->{descriptor};
    my $xs_state = Linux::Event::Stream::XSState->new(
        $self,
        fileno($fh),
        $descriptor->{xs},
    );
    $self->{xs_state} = $xs_state;

    my $initial_interest = 0x01;
    my $transport = $self->{transport};
    if (defined $transport) {
        my @binding;
        my $attached = eval {
            @binding = $transport->_stream_transport_bind(fileno($fh));
            $xs_state->_attach_transport(
                $transport, @binding[0, 1, 2],
            );
            1;
        };
        if (!$attached) {
            my $error = $@ || 'transport attachment failed';
            $xs_state->_close;
            $self->{xs_state} = undef;
            CORE::close($fh);
            $self->{fh} = undef;
            die $error;
        }
        $initial_interest = $binding[3] // 0;
    }

    $self->{initial_interest} = $initial_interest
        if $initial_interest != 0x01;
    return;
}

sub _configure_socket ($self, $fh, $role, $address) {
    my $callback = $self->{descriptor}{callbacks}{configure_socket};
    return if !$callback;
    my $ok = eval { $callback->($self, $fh, $role, $address); 1 };
    return if $ok;
    my $message = "$@";
    $message =~ s/\s+\z//;
    $message = 'configure_socket callback failed' if $message eq '';
    die Linux::Event::Error->new(
        type      => 'socket_configuration',
        operation => 'configure_socket',
        message   => $message,
    );
}

sub _attach_to_loop ($self, $loop) {
    croak 'add(): Stream is not unattached'
        if $self->{closed} || $self->{loop};
    $self->{loop} = $loop;
    if (my $connection = $self->{connection}) {
        my $attached = eval { $connection->_attach_to_loop($loop); 1 };
        if (!$attached) {
            my $failure = $@ || 'connection attachment failed';
            $self->{loop} = undef;
            die $failure;
        }
        return $self;
    }

    my $initial_interest = delete($self->{initial_interest}) // 0x01;
    my $watcher = eval {
        $loop->watch_fd(
            fileno($self->{fh}),
            fh    => $self->{fh},
            data  => $self->{xs_state},
            read  => \&Linux::Event::Stream::XSState::_read_ready,
            write => \&Linux::Event::Stream::XSState::_write_ready,
            error => \&_watch_error_xs_cb,
            _callback_data_arg => 1,
        );
    };
    if (!$watcher) {
        my $failure = $@ || 'Stream registration failed';
        $self->{loop} = undef;
        $self->{initial_interest} = $initial_interest;
        die $failure;
    }
    $self->{watcher} = $watcher;
    $watcher->disable_write if !($initial_interest & 0x02);
    $watcher->disable_read if !($initial_interest & 0x01);
    my $transport = $self->{transport};
    if ($transport && $transport->can('_stream_transport_start')) {
        my $started = eval { $transport->_stream_transport_start($self); 1 };
        if (!$started) {
            my $error = $@ || 'transport startup failed';
            $self->_close_now(1);
            die $error;
        }
    }
    $self->_flush_preconnect_output if exists $self->{preconnect_output};
    $self->_start_stream_deadlines if !$transport;
    return $self;
}

sub _connect_succeeded ($self, $fh) {
    return if $self->{closed};
    delete $self->{connection};
    $self->{fh} = $fh;
    $self->{local} = Linux::Event::Address->new(getsockname($fh));
    my $packed_peer = eval { getpeername($fh) };
    $self->{peer} = Linux::Event::Address->new($packed_peer)
        if defined $packed_peer;
    my $prepared = eval { $self->_prepare_fh($fh); 1 };
    if (!$prepared) {
        my $message = $@ || 'connected Stream setup failed';
        my $error = Linux::Event::Error->new(
            type => 'connect', operation => 'attach', message => $message,
        );
        $self->_fail($error);
        return;
    }
    my $initial_interest = delete($self->{initial_interest}) // 0x01;
    my $watcher = eval {
        $self->{loop}->watch_fd(
            fileno($self->{fh}),
            fh    => $self->{fh},
            data  => $self->{xs_state},
            read  => \&Linux::Event::Stream::XSState::_read_ready,
            write => \&Linux::Event::Stream::XSState::_write_ready,
            error => \&_watch_error_xs_cb,
            _callback_data_arg => 1,
        );
    };
    if (!$watcher) {
        my $message = "$@" || 'connected Stream registration failed';
        $self->_fail(Linux::Event::Error->new(
            type => 'setup', operation => 'watch', message => $message,
        ));
        return;
    }
    $self->{watcher} = $watcher;
    $watcher->disable_write if !($initial_interest & 0x02);
    $watcher->disable_read if !($initial_interest & 0x01);
    my $transport = $self->{transport};
    if ($transport && $transport->can('_stream_transport_start')) {
        my $started = eval { $transport->_stream_transport_start($self); 1 };
        if (!$started) {
            my $message = $@ || 'transport startup failed';
            my $error = Linux::Event::Error->new(
                type => 'transport', operation => 'start', message => $message,
            );
            $self->_fail($error);
            return;
        }
    }
    $self->_flush_preconnect_output;
    if (!$self->{transport}) {
        $self->_start_stream_deadlines;
        $self->_fire_ready;
    }
    return;
}

sub _connect_failed ($self, $connect_error) {
    return if $self->{closed};
    delete $self->{connection};
    $self->_fail($connect_error);
    return;
}

sub _fire_ready ($self) {
    return if $self->{closed} || ($self->{transport_ready_fired} & 0x02);
    $self->{transport_ready_fired} |= 0x02;
    if (my $callback = $self->{descriptor}{callbacks}{on_ready}) {
        $callback->($self);
    }
    return if $self->{closed};
    if ($self->{preconnect_write_blocked}
        && ($self->{preconnect_drain_reached}
            || !$self->{xs_state}->is_write_blocked)) {
        $self->_xs_drain;
    }
    return;
}

sub _flush_preconnect_output ($self) {
    my $queued = delete $self->{preconnect_output} // [];
    $self->{preconnect_output} = [];
    $self->{preconnect_bytes} = 0;
    for my $bytes (@$queued) {
        my $status = $self->{xs_state}->_write($bytes);
        $self->{watcher}->enable_write if $status & 0x02;
        last if $self->{closed};
    }
    if ($self->{write_ending} && !$self->{closed} && !$self->pending_bytes) {
        $self->_finish_write_side;
    }
    return;
}

sub fh ($self) { $self->{fh} }
sub loop ($self) { $self->{loop} }
sub peer ($self) { $self->{peer} }
sub local ($self) { $self->{local} }
sub state ($self) {
    return 'detached' if $self->{closed} && $self->{detached};
    return 'closed' if $self->{closed};
    return 'unattached' if !$self->{loop};
    return 'connecting' if $self->{connection};
    return 'active';
}
sub last_error ($self) { $self->{last_error} }
sub transport ($self) { $self->{transport} }
sub is_closed ($self) { !!$self->{closed} }
sub is_terminal ($self) { !!$self->{closed} }
sub is_read_paused ($self) { !!$self->{read_paused} }
sub is_read_eof ($self) { !!$self->{read_eof} }
sub is_write_ended ($self) { !!$self->{write_ended} }
sub is_write_blocked ($self) {
    return !!$self->{xs_state}->is_write_blocked if $self->{xs_state};
    return !!$self->{preconnect_write_blocked};
}

sub data ($self, @arg) {
    $self->{data} = $arg[0] if @arg;
    return $self->{data};
}

sub pending_bytes ($self) {
    my $pending = $self->{preconnect_bytes} // 0;
    $pending += $self->{xs_state}->pending_bytes if $self->{xs_state};
    return $pending;
}

sub transport_name ($self) {
    return $self->{xs_state}->transport_name if $self->{xs_state};
    return undef;
}

sub is_transport_ready ($self) {
    return !!$self->{xs_state}->transport_ready if $self->{xs_state};
    return 0;
}

sub selected_alpn ($self) {
    my $transport = $self->{transport};
    return undef if !$transport || !$transport->can('selected_alpn');
    return $transport->selected_alpn;
}

sub tls_protocol ($self) {
    my $transport = $self->{transport};
    return undef if !$transport || !$transport->can('protocol');
    return $transport->protocol;
}

sub tls_cipher ($self) {
    my $transport = $self->{transport};
    return undef if !$transport || !$transport->can('cipher');
    return $transport->cipher;
}

sub tls_stats ($self) {
    my $transport = $self->{transport};
    return undef if !$transport || !$transport->can('stats');
    return $transport->stats;
}

sub idle_timeout  ($self) { $self->{timeout}{idle_timeout} }
sub read_timeout  ($self) { $self->{timeout}{read_timeout} }
sub write_timeout ($self) { $self->{timeout}{write_timeout} }

sub _socket_option ($self, $name, @argument) {
    croak "$name(): Stream has no established socket"
        if $self->{closed} || !defined($self->{fh});
    croak "$name(): expected zero or one argument" if @argument > 1;
    my $family = $self->{local}
        ? $self->{local}->family_number
        : Linux::Event::Address->new(getsockname($self->{fh}))->family_number;
    Linux::Event::_SocketConfig::set_option(
        $self->{fh}, $family, $name, $argument[0],
    ) if @argument;
    return Linux::Event::_SocketConfig::get_option(
        $self->{fh}, $family, $name,
    );
}

sub tcp_nodelay ($self, @argument) {
    return $self->_socket_option('tcp_nodelay', @argument);
}
sub keepalive ($self, @argument) {
    return $self->_socket_option('keepalive', @argument);
}
sub keepalive_idle ($self, @argument) {
    return $self->_socket_option('keepalive_idle', @argument);
}
sub keepalive_interval ($self, @argument) {
    return $self->_socket_option('keepalive_interval', @argument);
}
sub keepalive_count ($self, @argument) {
    return $self->_socket_option('keepalive_count', @argument);
}
sub tcp_user_timeout ($self, @argument) {
    return $self->_socket_option('tcp_user_timeout', @argument);
}
sub send_buffer ($self, @argument) {
    return $self->_socket_option('send_buffer', @argument);
}
sub receive_buffer ($self, @argument) {
    return $self->_socket_option('receive_buffer', @argument);
}

sub set_deadline ($self, %option) {
    croak 'set_deadline(): stream is closed' if $self->{closed};
    my $spec = _deadline_spec('set_deadline', \%option);
    if (!$self->{deadline_started}) {
        $self->{initial_deadline} = $spec;
        return $self;
    }
    my $now = _deadline_now();
    $self->{operation_deadline_at} = $spec->{absolute}
        ? $spec->{seconds} : $now + $spec->{seconds};
    $self->{operation_deadline_name} = $spec->{operation};
    $self->{operation_deadline_timeout} = $spec->{absolute}
        ? undef : $spec->{seconds};
    $self->_rearm_stream_deadline;
    return $self;
}

sub clear_deadline ($self) {
    croak 'clear_deadline(): stream is closed' if $self->{closed};
    $self->{initial_deadline} = undef;
    $self->{operation_deadline_at} = undef;
    $self->{operation_deadline_name} = undef;
    $self->{operation_deadline_timeout} = undef;
    $self->_rearm_stream_deadline if $self->{deadline_started};
    return $self;
}

sub deadline ($self) {
    return $self->{operation_deadline_at}
        if defined $self->{operation_deadline_at};
    my $spec = $self->{initial_deadline} or return undef;
    return $spec->{seconds} if $spec->{absolute};
    return undef;
}

sub deadline_operation ($self) {
    return $self->{operation_deadline_name}
        // ($self->{initial_deadline} && $self->{initial_deadline}{operation});
}

sub _deadline_now () {
    require Linux::Event::Timer;
    return Linux::Event::Stream::_Deadline->now;
}

sub _needs_activity_tracking ($self) {
    return $self->{timeout}{idle_timeout} > 0
        || $self->{timeout}{read_timeout} > 0
        || $self->{timeout}{write_timeout} > 0;
}

sub _start_stream_deadlines ($self) {
    return if $self->{closed} || $self->{deadline_started};
    return if !$self->{loop} || !$self->{xs_state};
    $self->{deadline_started} = 1;
    return if !$self->_needs_activity_tracking
        && !$self->{initial_deadline};
    my $now = _deadline_now();
    if ($self->_needs_activity_tracking) {
        $self->{xs_state}->_set_activity_tracking(1);
        $self->{deadline_tracking} = 1;
    }
    $self->{deadline_read_started} = $now;
    $self->{deadline_write_started} = $now if $self->pending_bytes > 0;
    if (my $spec = delete $self->{initial_deadline}) {
        $self->{operation_deadline_at} = $spec->{absolute}
            ? $spec->{seconds} : $now + $spec->{seconds};
        $self->{operation_deadline_name} = $spec->{operation};
        $self->{operation_deadline_timeout} = $spec->{absolute}
            ? undef : $spec->{seconds};
    }
    $self->_rearm_stream_deadline;
    return;
}

sub _deadline_candidates ($self) {
    my @candidate;
    if (defined $self->{operation_deadline_at}) {
        push @candidate, {
            at        => $self->{operation_deadline_at},
            operation => $self->{operation_deadline_name},
            timeout   => $self->{operation_deadline_timeout},
            priority  => 0,
        };
    }

    my ($last_read, $last_write);
    if ($self->{deadline_tracking} && $self->{xs_state}) {
        ($last_read, $last_write)
            = $self->{xs_state}->_activity_snapshot;
    }
    my $idle = $self->{timeout}{idle_timeout};
    if ($idle > 0) {
        my $last = $last_read > $last_write ? $last_read : $last_write;
        push @candidate, {
            at => $last + $idle, operation => 'idle', timeout => $idle,
            priority => 3,
        };
    }
    my $read = $self->{timeout}{read_timeout};
    if ($read > 0 && !$self->{read_paused} && !$self->{read_eof}) {
        my $last = $last_read;
        $last = $self->{deadline_read_started}
            if defined($self->{deadline_read_started})
            && $self->{deadline_read_started} > $last;
        push @candidate, {
            at => $last + $read, operation => 'read', timeout => $read,
            priority => 2,
        };
    }
    my $write = $self->{timeout}{write_timeout};
    if ($write > 0 && !$self->{write_ended} && $self->pending_bytes > 0) {
        my $last = $last_write;
        $last = $self->{deadline_write_started}
            if defined($self->{deadline_write_started})
            && $self->{deadline_write_started} > $last;
        push @candidate, {
            at => $last + $write, operation => 'write', timeout => $write,
            priority => 1,
        };
    }
    return @candidate;
}

sub _rearm_stream_deadline ($self) {
    return if !$self->{deadline_started} || $self->{closed};
    my @candidate = sort {
        $a->{at} <=> $b->{at} || $a->{priority} <=> $b->{priority}
    } $self->_deadline_candidates;
    if (!@candidate) {
        if (my $timer = delete $self->{deadline_timer}) {
            $timer->cancel;
        }
        return;
    }

    my $at = $candidate[0]{at};
    if (my $timer = $self->{deadline_timer}) {
        if ($timer->is_active) {
            $timer->reschedule(at => $at);
            return;
        }
    }

    my $state = { stream => $self };
    weaken($state->{stream});
    my $timer = Linux::Event::Stream::_Deadline->new(
        at => $at, data => $state,
    );
    $self->{deadline_timer} = $timer;
    $self->{loop}->add($timer);
    return;
}

sub _stream_deadline_fired ($self, $timer) {
    return if $self->{closed} || $self->{deadline_timer} != $timer;
    my $now = _deadline_now();
    my @candidate = sort {
        $a->{at} <=> $b->{at} || $a->{priority} <=> $b->{priority}
    } $self->_deadline_candidates;
    my ($expired) = grep { $_->{at} <= $now } @candidate;
    if (!$expired) {
        $self->_rearm_stream_deadline;
        return;
    }

    my $operation = $expired->{operation};
    my $error = Linux::Event::Error->new(
        type      => 'timeout',
        operation => $operation,
        message   => "$operation deadline expired",
        timeout   => $expired->{timeout},
        deadline  => $expired->{at},
    );
    $self->_fail($error);
    return;
}

sub _cancel_stream_deadline ($self) {
    if (my $timer = delete $self->{deadline_timer}) {
        $timer->cancel;
    }
    if ($self->{deadline_tracking} && $self->{xs_state}) {
        $self->{xs_state}->_set_activity_tracking(0);
    }
    $self->{deadline_tracking} = 0;
    $self->{deadline_started} = 0;
    return;
}

sub _apply_transition_timeouts ($self, $descriptor) {
    for my $name (qw(idle_timeout read_timeout write_timeout)) {
        $self->{timeout}{$name} = $descriptor->{options}{$name}
            if !exists $self->{timeout_override}{$name};
    }
    return if !$self->{deadline_started} || !$self->{xs_state};
    $self->{xs_state}->_set_activity_tracking(0)
        if $self->{deadline_tracking};
    $self->{deadline_tracking} = 0;
    my $now = _deadline_now();
    if ($self->_needs_activity_tracking) {
        $self->{xs_state}->_set_activity_tracking(1);
        $self->{deadline_tracking} = 1;
    }
    $self->{deadline_read_started} = $now;
    $self->{deadline_write_started} = $self->pending_bytes > 0 ? $now : undef;
    $self->_rearm_stream_deadline;
    return;
}

sub write ($self, $bytes) {
    croak 'write(): stream is closed' if $self->{closed};
    croak 'write(): writable side has ended'
        if $self->{write_ending} || $self->{write_ended};
    return 1 if !defined $bytes;
    croak 'write(): bytes must be a scalar byte string' if ref $bytes;
    $bytes = "$bytes";
    croak 'write(): bytes must be a scalar byte string'
        if !utf8::downgrade($bytes, 1);
    return 1 if $bytes eq '';

    if (!$self->{xs_state}) {
        croak 'write(): stream has no pending or active transport'
            if !$self->{connection};
        my $pending = ($self->{preconnect_bytes} // 0) + length($bytes);
        my $limit = $self->{descriptor}{options}{max_pending_bytes};
        if ($limit && $pending > $limit) {
            my $error = Linux::Event::Error->new(
                type          => 'output_limit',
                operation     => 'write',
                message       => "pending output would exceed $limit bytes",
                pending_bytes => $pending,
                limit         => $limit,
            );
            $self->_fail($error);
            return 0;
        }
        push @{ $self->{preconnect_output} //= [] }, "$bytes";
        $self->{preconnect_bytes} = $pending;
        if ($pending > $self->{descriptor}{options}{high_watermark}) {
            $self->{preconnect_write_blocked} = 1;
            return 0;
        }
        return 1;
    }

    my $was_pending = $self->pending_bytes;
    my $status = $self->{xs_state}->_write($bytes);
    $self->{watcher}->enable_write if $status & 0x02;
    if ($self->{deadline_started} && $self->{timeout}{write_timeout} > 0
        && !$was_pending && $self->pending_bytes > 0) {
        $self->{deadline_write_started} = _deadline_now();
        $self->_rearm_stream_deadline;
    }
    return $status & 0x01 ? 1 : 0;
}

sub send ($self, $payload) {
    my $framer = $self->{descriptor}{framer}
        // croak 'send(): requires a framed Stream subclass';
    my $bytes = $framer->{frame}->($framer->{native}, $payload);
    return $self->write($bytes);
}

sub end ($self, $final_bytes = undef) {
    return $self
        if $self->{closed} || $self->{write_ending} || $self->{write_ended};
    $self->write($final_bytes) if defined($final_bytes) && $final_bytes ne '';
    $self->{write_ending} = 1;
    $self->_finish_write_side
        if $self->{xs_state} && $self->pending_bytes == 0;
    return $self;
}

sub pause_read ($self) {
    return $self if $self->{closed} || $self->{read_eof} || $self->{read_paused};
    $self->{read_paused} = 1;
    $self->{xs_state}->_pause if $self->{xs_state};
    $self->{watcher}->disable_read if $self->{watcher};
    $self->_rearm_stream_deadline if $self->{deadline_started};
    return $self;
}

sub resume_read ($self) {
    return $self if $self->{closed} || $self->{read_eof} || !$self->{read_paused};
    $self->{read_paused} = 0;
    $self->{deadline_read_started} = _deadline_now()
        if $self->{deadline_started};
    $self->{xs_state}->_resume if $self->{xs_state};
    $self->{watcher}->enable_read if $self->{watcher};
    $self->_rearm_stream_deadline if $self->{deadline_started};
    return $self;
}

sub transition_to ($self, $class, %opt) {
    croak 'transition_to(): stream is closed' if $self->{closed};
    croak 'transition_to(): target class is required'
        if !defined($class) || ref($class) || $class eq '';
    croak "transition_to(): $class is already active"
        if ref($self) eq $class;

    my $input = delete $opt{input};
    croak 'transition_to(): input must be a byte string'
        if defined($input) && ref($input);
    if (defined $input) {
        $input = "$input";
        croak 'transition_to(): input must be a byte string'
            if !utf8::downgrade($input, 1);
    }
    croak 'transition_to(): unknown options: ' . join(', ', sort keys %opt)
        if %opt;

    my $descriptor = _descriptor_for($class);
    my $xs_state = $self->{xs_state}
        // croak 'transition_to(): stream has no native state';

    # XS validates and swaps the immutable descriptor without invoking a
    # callback. Update the Perl object's type before buffered input is allowed
    # to enter the new callback set.
    $xs_state->_transition($descriptor->{xs}, $input);
    $self->{descriptor} = $descriptor;
    bless $self, $class;
    $self->_apply_transition_timeouts($descriptor);
    $xs_state->_transition_ready;
    return $self;
}

sub close ($self) {
    $self->_close_now(1);
    return $self;
}

sub detach ($self) {
    croak 'detach(): stream is already closed' if $self->{closed};
    croak 'detach(): stream is not established' if !defined $self->{fh};
    croak 'detach(): cannot detach a non-plain transport'
        if ($self->transport_name // 'plain') ne 'plain';
    my $fh = $self->{fh};
    $self->_cancel_stream_deadline;
    if (my $xs_state = delete $self->{xs_state}) {
        $xs_state->_close;
    }
    if (my $watcher = delete $self->{watcher}) {
        $watcher->cancel;
    }
    $self->{closed} = 1;
    $self->{detached} = 1;
    $self->{fh} = undef;
    return $fh;
}

sub _on_terminal_ready ($self) {
    return if $self->{closed};

    my $packed = getsockopt($self->{fh}, SOL_SOCKET, SO_ERROR);
    if (defined $packed) {
        my $errno = unpack('i', $packed);
        if ($errno) {
            local $! = $errno;
            $self->_fail_io('socket', $errno);
            return;
        }
    }

    $self->{xs_state}->_read_ready
        if !$self->{read_paused} && !$self->{read_eof} && $self->{xs_state};
}

sub _finish_write_side ($self) {
    return if $self->{closed} || $self->{write_ended};
    return if $self->pending_bytes > 0;

    if (!$self->{transport_shutdown_started}++ && $self->{transport}
        && $self->{transport}->can('_stream_transport_begin_shutdown')) {
        my $started = eval {
            $self->{transport}->_stream_transport_begin_shutdown($self);
            1;
        };
        if (!$started) {
            my $error = Linux::Event::Error->new(
                type      => $self->transport_name,
                operation => 'shutdown',
                message   => $@ || 'transport shutdown setup failed',
            );
            $self->_fail($error);
            return;
        }
    }

    my ($status, $errno, $message) = $self->{xs_state}->_shutdown_write;
    if ($status == 2) {
        $self->{watcher}->enable_read if $self->{watcher};
        return;
    }
    if ($status == 3) {
        $self->{watcher}->enable_write if $self->{watcher};
        return;
    }
    if ($status == 5) {
        if (($self->transport_name // 'plain') ne 'plain') {
            my $error = Linux::Event::Error->new(
                type      => $self->transport_name,
                operation => 'shutdown',
                message   => $message || 'transport shutdown failed',
            );
            $self->_fail($error);
            return;
        }
        local $! = $errno;
        $self->_fail_io('shutdown', $errno);
        return;
    }

    $self->{write_ending} = 0;
    $self->{write_ended} = 1;
    $self->_clear_transport_deadline;
    $self->_close_now(1) if $self->{read_eof};
}

sub _set_transport_deadline_watcher ($self, $watcher) {
    return if $self->{transport_deadline_watcher};
    $self->{transport_deadline_watcher} = $watcher;
    return;
}

sub _has_transport_deadline_watcher ($self) {
    return !!$self->{transport_deadline_watcher};
}

sub _clear_transport_deadline ($self) {
    if ($self->{transport}
        && $self->{transport}->can('_stream_transport_cancel_deadline')) {
        $self->{transport}->_stream_transport_cancel_deadline;
    }
    return;
}

sub _destroy_transport_deadline ($self) {
    if (my $watcher = delete $self->{transport_deadline_watcher}) {
        $watcher->cancel;
    }
    if ($self->{transport}
        && $self->{transport}->can('_stream_transport_close_deadline')) {
        $self->{transport}->_stream_transport_close_deadline;
    }
    return;
}

sub _transport_deadline_expired ($self, $operation, $message) {
    return if $self->{closed};
    my $error = Linux::Event::Error->new(
        type      => $self->transport_name // 'transport',
        operation => $operation,
        message   => $message,
    );
    $self->_fail($error);
    return;
}

sub _mark_eof ($self) {
    return if $self->{read_eof} || $self->{closed};
    $self->{read_eof} = 1;
    $self->{watcher}->disable_read if $self->{watcher};
    $self->_rearm_stream_deadline if $self->{deadline_started};

    if (my $callback = $self->{descriptor}{callbacks}{on_eof}) {
        $callback->($self);
    }
    $self->_close_now(1) if $self->{write_ended};
}

sub _fail_io ($self, $operation, $errno) {
    local $! = $errno;
    my $error = Linux::Event::Error->new(
        type      => 'io',
        operation => $operation,
        errno     => $errno,
        message   => "$!",
    );
    $self->_fail($error);
}

sub _fail_framing ($self, $message) {
    my $error = Linux::Event::Error->new(
        type      => 'framing',
        operation => 'frame',
        message   => $message,
    );
    $self->_fail($error);
}

sub _fail ($self, $error) {
    return if $self->{closed};
    $self->{last_error} = $error;
    my $failure;
    if (my $callback = $self->{descriptor}{callbacks}{on_error}) {
        my $reported = eval { $callback->($self, $error); 1 };
        $failure = $@ if !$reported;
    }
    my $closed = eval { $self->_close_now(1); 1 };
    $failure //= $@ if !$closed;
    die $failure if defined $failure;
    return;
}

sub _close_now ($self, $close_fh) {
    return if $self->{closed};
    $self->{closed} = 1;
    if (my $connection = delete $self->{connection}) {
        $connection->cancel;
    }
    $self->{preconnect_output} = [];
    $self->{preconnect_bytes} = 0;
    delete $self->{preconnect_write_blocked};
    delete $self->{preconnect_drain_reached};
    $self->_cancel_stream_deadline;
    $self->_destroy_transport_deadline;

    if (my $xs_state = delete $self->{xs_state}) {
        $xs_state->_close;
    }
    if (my $watcher = delete $self->{watcher}) {
        $watcher->cancel;
    }
    CORE::close($self->{fh}) if $close_fh && defined $self->{fh};
    $self->{fh} = undef;

    if (!$self->{detached} && !$self->{close_fired}++) {
        if (my $callback = $self->{descriptor}{callbacks}{on_close}) {
            $callback->($self);
        }
    }
}

sub _set_nonblocking ($fh) {
    my $flags = fcntl($fh, F_GETFL, 0);
    croak "new(): fcntl(F_GETFL): $!" if !defined $flags;
    if (!($flags & O_NONBLOCK)) {
        fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
            or croak "new(): fcntl(F_SETFL O_NONBLOCK): $!";
    }
    my $descriptor_flags = fcntl($fh, F_GETFD, 0);
    croak "new(): fcntl(F_GETFD): $!" if !defined $descriptor_flags;
    if (!($descriptor_flags & FD_CLOEXEC)) {
        fcntl($fh, F_SETFD, $descriptor_flags | FD_CLOEXEC)
            or croak "new(): fcntl(F_SETFD FD_CLOEXEC): $!";
    }
}

1;

package Linux::Event::Stream::XSDescriptor;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Stream::XSState;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Stream::_Deadline;
use parent -norequire, 'Linux::Event::Timer';

sub on_timer ($timer) {
    my $state = $timer->data;
    my $stream = $state->{stream};
    $stream->_stream_deadline_fired($timer) if $stream;
    return;
}

package Linux::Event::Stream;

__END__

=head1 NAME

Linux::Event::Stream - subclass-defined native buffered streams

=head1 SYNOPSIS

  use v5.36;
  use Linux::Event::Loop;

  package EchoStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($stream, $message) {
      $stream->send($message);
  }

  sub on_eof ($stream) {
      $stream->end;
  }

  sub on_error ($stream, $error) {
      warn "$error\n";
  }

  package main;
  my $loop = Linux::Event::Loop->new;
  my $stream = $loop->add(EchoStream->new(
      fh   => $socket,          # required
      data => { user_id => 42 }, # optional
  ));
  $loop->run;

=head1 DESCRIPTION

C<Linux::Event::Stream> is a resource-owning object backed by the native
buffered byte-stream engine above L<Linux::Event::Loop>. It is a base class
rather than a configurable Stream type. Applications define behavior once in a
subclass and construct lightweight per-connection instances containing only
changing connection state.

The first construction of each subclass resolves its inherited callback CVs,
framer and TLS declarations, parser configuration, and Stream policy into one
cached descriptor. XS stores that descriptor once and every connection's
native state references it. Construction therefore avoids per-object callback
hashes, framer objects, repeated validation, and repeated native configuration
copies.

=head1 DEFINING A STREAM TYPE

A raw subclass defines C<on_data> and does not declare a framer:

  package ByteStream;
  use parent 'Linux::Event::Stream';

  sub on_data ($stream, $bytes) {
      $stream->write($bytes);
  }

A framed subclass imports one native built-in and defines C<on_message>:

  package LineStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($stream, $message) {
      $stream->send($message);
  }

Framed and raw modes are mutually exclusive. A subclass with no framer must
define C<on_data>; a framed subclass must define C<on_message>. The base class
cannot be instantiated directly.

=head1 CONSTRUCTOR

=head2 new(fh => $fh, loop => $loop, data => $value)

C<fh> is required for an already-established Stream. Stream takes ownership of
the filehandle, sets it nonblocking, and enables close-on-exec. Supply C<loop>
to attach before C<new> returns, or omit it and attach with
C<< $loop->add($stream) >>. Both forms are primary APIs and C<add> returns the
same Stream. C<data> is optional per-connection state. Use C<detach> to transfer
a still-open plain handle back to the application; TLS Streams cannot be
detached.

A TLS-declared Stream normally obtains its role from C<connect> or Listener
acceptance. Supplying an already-connected C<fh> is ambiguous, so that advanced
form also requires C<tls_role =E<gt> 'client'> or C<'server'>. See
L<Linux::Event::TLS>.

C<idle_timeout>, C<read_timeout>, and C<write_timeout> override the subclass's
cached inactivity defaults for this Stream. Each is non-negative seconds and
zero explicitly disables that policy. C<deadline> accepts a hash reference
containing exactly one of C<after> or C<at> plus a non-empty C<operation> label.
Relative construction deadlines begin when the Stream becomes usable.

Socket policy such as C<tcp_nodelay>, C<keepalive>, and buffer sizes may also
be supplied here for an established C<fh>. Constructor values override the
subclass policy. Settings omitted from both places leave the kernel value
unchanged.

Callbacks, framing, and buffer policy are class behavior and are not accepted
as constructor options.

=head2 connect(host => 'example.com', port => 443)

  my $stream = MyStream->connect(
      host         => '127.0.0.1', # required
      port         => 9999,        # required
      timeout      => 10,          # default
      local_host   => '127.0.0.1', # optional source address
      local_port   => 0,           # optional source port
      tcp_nodelay  => 1,           # optional
  );
  $loop->add($stream);

Returns one Stream that survives connection setup, optional TLS negotiation,
established I/O, and close. Supply C<loop> to start connecting immediately.
Otherwise the state is C<unattached> until C<< $loop->add($stream) >>.

Exactly one of C<host>/C<port>, C<unix>, or packed C<sockaddr>/C<family> is
required. C<timeout> is seconds, defaults to 10, and may be zero to disable the
deadline. C<data>, established timeout overrides, and C<deadline> are passed to
the Stream. A class declaring L<Linux::Event::TLS> automatically uses client
TLS and defaults certificate hostname verification to C<host>. C<write> and
C<send> may queue output before attachment or readiness. Hostname resolution
runs in the Loop's private native worker pool; socket establishment and
staggered IPv6/IPv4 attempts are nonblocking.

Most outbound connections should omit C<local_host> and C<local_port>; Linux
then chooses the source address and ephemeral source port. C<local_host>
selects a numeric IPv4 or IPv6 source address, while C<local_port> selects the
source port. They do not replace the remote C<host> and C<port>.
C<bind_device> optionally constrains the socket to a Linux interface before
local binding and connection. It may require kernel privilege.

=head1 ATTACHMENT AND OWNERSHIP

A Stream is attached once, to one Loop. C<loop =E<gt> $loop> and
C<< $loop->add($stream) >> perform the same attachment. A terminal Stream cannot
be reused or reattached. The Stream owns its filehandle until C<close>, graceful
completion, or C<detach> transfers a plain handle back to the caller.

=head1 TLS DECLARATION

A subclass opts into TLS declaratively, after establishing Stream inheritance:

  package SecureStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::TLS
      ca_file           => '/etc/ssl/certs/ca-certificates.crt', # optional
      verify            => 1,                                   # default
      alpn              => ['http/1.1'],                        # optional
      handshake_timeout => 10,                                  # default
      shutdown_timeout  => 5;                                   # default

C<< SecureStream->connect(host =E<gt> 'example.com', port =E<gt> 443) >>
selects client TLS. A Listener that names
C<SecureStream> selects server TLS and therefore requires C<cert_file> and
C<key_file> in the declaration. C<on_ready> has one meaning in both roles: the
plain connection or TLS handshake is ready for application traffic.

TLS is an acquisition declaration, not protocol inheritance. It creates fresh
connection state only when a Stream is constructed. C<transition_to> changes
protocol callbacks and framing but never installs, removes, or replaces the
active byte transport.

=head1 CLASS STREAM OPTIONS

A subclass that needs non-default Stream settings may define
C<stream_options>. It runs once when the class descriptor is built, not once
per connection:

  sub stream_options ($class) {
      return (
          read_size         => 32_768,            # optional
          high_watermark    => 2 * 1024 * 1024,   # optional
          low_watermark     => 512 * 1024,        # optional
          max_pending_bytes => 8 * 1024 * 1024,   # optional
          max_buffer        => 16 * 1024 * 1024,  # optional
          idle_timeout      => 120,               # optional; seconds
          read_timeout      => 30,                # optional; seconds
          write_timeout     => 10,                # optional; seconds
      );
  }

The defaults are 65,536 bytes per read, a 1 MiB high watermark, a 256 KiB low
watermark, no hard pending-output limit, and an 8 MiB maximum framed input
buffer. Set C<max_pending_bytes> to a positive byte count to impose a hard
limit; zero keeps the default unlimited policy. Established timeout defaults
are zero, which disables them. Constructor values take precedence for one
Stream and survive protocol transitions; non-overridden values change to the
target subclass's defaults.

=head1 SOCKET CONFIGURATION

Socket policy may be cached with the other C<stream_options>:

  sub stream_options ($class) {
      return (
          tcp_nodelay       => 1,       # optional
          keepalive         => 1,       # optional
          keepalive_idle    => 60,      # optional; seconds
          keepalive_interval => 10,     # optional; seconds
          keepalive_count   => 5,       # optional
          tcp_user_timeout  => 15,      # optional; seconds
          send_buffer       => 262_144, # optional; bytes
          receive_buffer    => 262_144, # optional; bytes
      );
  }

The same names are accepted by C<new> and C<connect> for one Stream. Instance
construction wins over class policy; an option omitted from both places is not
set at all. This is deliberately different from inventing library defaults
that overwrite Linux tuning silently.

C<tcp_nodelay>, C<keepalive>, C<keepalive_idle>,
C<keepalive_interval>, C<keepalive_count>, and C<tcp_user_timeout> are valid
only for IPv4 or IPv6 TCP sockets. Send and receive buffer sizing also applies
to Unix Streams. Public timeout values are seconds;
C<tcp_user_timeout> is converted to the Linux millisecond value with a positive
sub-millisecond duration rounded up.

For outbound sockets, built-in policy and the optional hook below run after
C<socket> and before local C<bind> or remote C<connect>. Accepted and adopted
sockets apply policy before transport setup, including a TLS handshake.

An advanced subclass may define one cached socket hook:

  use Socket qw(IPPROTO_TCP TCP_QUICKACK);

  sub configure_socket ($stream, $fh, $role, $address) {
      setsockopt($fh, IPPROTO_TCP, TCP_QUICKACK, pack('i', 1))
          or die "setsockopt(TCP_QUICKACK): $!";
  }

C<$role> is C<connect>, C<accepted>, or C<adopted>. C<$address> is the remote
candidate or peer when one is available. A hook exception becomes a structured
C<socket_configuration> Error. It never falls back silently to another
configuration.

These options are also live getters/setters on an established Stream:

  my $enabled = $stream->tcp_nodelay;    # current kernel value
  $stream->tcp_nodelay(1);               # enable and return effective value
  my $bytes = $stream->send_buffer(262_144);

The complete live set is C<tcp_nodelay>, C<keepalive>, C<keepalive_idle>,
C<keepalive_interval>, C<keepalive_count>, C<tcp_user_timeout>,
C<send_buffer>, and C<receive_buffer>. Linux may round or double buffer
requests, so setters return the value read back from the kernel. Socket policy
is acquisition policy; C<transition_to> does not reapply it.

=head1 CALLBACKS

Subclasses may define these ordinary named methods:

  sub on_data ($stream, $bytes) {             # required for raw Stream
      $stream->write($bytes);
  }

  sub on_message ($stream, $message) {        # required for framed Stream
      $stream->send($message);
  }

  sub on_drain ($stream) {                    # optional
      $stream->data->{blocked} = 0 if $stream->data;
  }

  sub on_eof ($stream) { $stream->end }       # optional
  sub on_error ($stream, $error) {            # optional
      warn "$error\n";
  }
  sub on_close ($stream) {                    # optional
      $stream->data->{closed} = 1 if $stream->data;
  }
  sub on_ready ($stream) {                    # optional
      $stream->write("ready\n");
  }
  sub on_transport_ready ($stream) {          # optional
      say "transport " . $stream->transport_name . " is ready";
  }

The resolved CVs are cached and invoked directly; readiness dispatch does not
perform Perl method lookup. Inheritance works normally, so a derived Stream type
may reuse callbacks and framing from its parent. Per-user or per-connection
permissions belong in C<data>, which callbacks access through C<< $stream->data >>.
C<on_ready> is called once when an asynchronously acquired Stream becomes
usable. For TLS, this means handshake and verification have completed. Accepted
Streams are ready after Listener attachment. C<on_transport_ready> is the
lower-level provider-ready notification and runs immediately before C<on_ready>
for an asynchronous non-plain transport. Most applications need only
C<on_ready>.

Application callback exceptions are not swallowed.

=head1 METHODS

=head2 write($bytes)

Writes immediately when possible and queues any remainder. Returns false after
queued bytes exceed the high watermark; the bytes were still accepted. Wait for
C<on_drain> before producing more. Output queued before attachment or connection
readiness uses the same return contract and produces one drain notification if
that blocked interval clears during establishment.

C<$bytes> must be a byte string. Encode character text before writing it.

When C<max_pending_bytes> is nonzero, a write whose unsent remainder would put
the native queue above that limit is not queued. Stream reports an
C<output_limit> L<Linux::Event::Error> through C<on_error> and closes.
The error's C<pending_bytes> and C<limit> accessors describe the attempted
queue size and configured bound. An immediate kernel write may already have
sent a prefix before its remainder is found to exceed the limit; Stream never
adds that remainder to its queue. The ordinary false return remains reserved
for accepted cooperative backpressure.

=head2 send($payload)

Available only to framed subclasses. Applies the subclass's declared outbound
wire framing and then uses C<write>. Serialization remains separate.

=head2 pause_read / resume_read

Disable and re-enable input readiness without destroying the Stream.

=head2 transition_to($class, input => $bytes)

Changes a live connection to another loaded C<Linux::Event::Stream> subclass.
The same object is reblessed into C<$class>, and the same filehandle, native registration,
native connection state, output queue, backpressure state, lifecycle state, and
C<data> are retained. Future callbacks, C<send> framing, parser rules, and class
Stream policy come from the target subclass's cached descriptor.

Unread bytes already held by a framed parser are preserved and reinterpreted by
the target parser. A raw C<on_data> callback may pass the unconsumed suffix of
its current chunk with C<< input => $bytes >>:

  sub on_data ($stream, $bytes) {
      my ($request, $remaining) = parse_upgrade($bytes);
      return if !$request;
      $stream->write(upgrade_response());
      $stream->transition_to(
          'My::WebSocketStream',
          input => $remaining, # optional raw unconsumed suffix
      );
      return;
  }

Existing native input is ordered before the explicit C<input> suffix. Complete
target frames may be delivered before C<transition_to> returns when the method
is called outside input dispatch. During C<on_data> or C<on_message>, target
dispatch begins after the old callback returns. Code should normally return
immediately after requesting a transition.

Read pause is retained and continues to gate preserved input. Queued output
keeps its original byte ordering; only later C<send> calls use the new outbound
framing. If preserved input exceeds the target class's C<max_buffer>, or
existing queued output exceeds its nonzero C<max_pending_bytes>, the transition
fails atomically and the old type remains active. Transitioning to the
already-active class is rejected.

This method changes Stream protocol behavior; it does not replace the active
byte transport. In particular, a TLS Stream remains TLS across protocol
transitions.

=head2 end($final_bytes = undef)

Drains queued output and ends the transport's writable side. Plain Streams use
C<shutdown(SHUT_WR)>; TLS providers send C<close_notify>. Peer EOF and the local
writable half-close remain independent.

=head2 close

Immediately cancels native readiness and closes the owned descriptor. Queued
output may be lost. Returns the Stream.

=head2 detach

Cancels Stream ownership and returns the still-open filehandle for the plain
transport. C<on_close> is not called because the underlying resource remains
open. Non-plain transports reject detach because the descriptor carries
provider-owned wire state rather than application plaintext.

=head2 pending_bytes / is_write_blocked

Report total output-queue and flow-control state, including output accepted
while an outbound connection is still being established.

=head2 idle_timeout / read_timeout / write_timeout

Return this Stream's effective established inactivity policy in seconds.
C<idle_timeout> resets on successful read or write transport progress.
C<read_timeout> resets on inbound bytes, is suspended by C<pause_read>, and
starts a fresh interval on C<resume_read>. C<write_timeout> exists only while
output remains queued and resets on successful write progress.

=head2 set_deadline(after => 5, operation => 'response')

Set or replace the one explicit overall-operation deadline and return the
Stream. Supply C<after =E<gt> $seconds> or
C<at =E<gt> $monotonic_deadline>, together with
C<operation =E<gt> $name>. An overall deadline never resets because of I/O.
Calling this before establishment stores the policy; relative time begins when
the Stream becomes usable, while C<at> remains an absolute C<CLOCK_MONOTONIC>
value.

=head2 clear_deadline

Remove the explicit operation deadline and return the Stream. Inactivity
policies remain active.

=head2 deadline / deadline_operation

Return the active absolute operation deadline and its label. A detached
relative deadline has no absolute value yet, so C<deadline> returns undef.

All established deadline categories start after plain or TLS transport
readiness. Resolver, connection, TLS handshake, and TLS shutdown time use their
existing separate owners. Expiration reports a C<timeout>
L<Linux::Event::Error> through C<on_error> and closes normally through
C<on_close>. The Error includes C<timeout> and C<deadline> context. Every
deadline-enabled Stream uses at most one private Timer in the Loop's shared
timerfd/native heap.

=head2 transport / transport_name / is_transport_ready

Returns the configured provider object, active native byte transport name, and
whether its asynchronous setup has completed. Ordinary filehandle-backed
Streams have no provider object, report C<plain>, and are immediately ready.

=head2 selected_alpn / tls_protocol / tls_cipher / tls_stats

Return negotiated ALPN, TLS protocol, cipher, and native TLS counters for a TLS
Stream. The scalar information methods return undef for a plain Stream;
C<tls_stats> returns undef when no TLS provider is active.

=head2 tcp_nodelay / keepalive / keepalive_idle / keepalive_interval / keepalive_count / tcp_user_timeout / send_buffer / receive_buffer

With no argument, return the effective Linux socket value. With one argument,
set the option and return the value read back from the kernel. These methods
require an established socket; TCP-only methods reject a Unix Stream.

=head2 is_read_paused / is_read_eof / is_write_ended / is_closed

Report Stream lifecycle state.

=head2 data([$value])

Gets or replaces per-connection application state.

=head2 loop / state / peer / local

Return the owning Loop, C<unattached>, C<connecting>, C<active>, C<detached>, or
C<closed> lifecycle state, the lazy remote peer when available, and the local
socket address. Outbound and adopted Streams populate both addresses when the
kernel supplies them; accepted Streams receive their peer from Listener.

=head2 last_error

Returns the L<Linux::Event::Error> that caused closure, or undef when the Stream
has not failed.

=head1 FRAMING POLICY

Framed Stream types use native built-ins declared through
L<Linux::Event::Framer>. Arbitrary per-connection framer objects and the
old custom Perl C<next_frame> contract are intentionally unsupported. Unusual
protocols can buffer and parse raw C<on_data> bytes. Generally useful framing
families should be implemented as native Linux::Event built-ins.

=head1 PERFORMANCE

Native code drains reads, detects built-in frame boundaries, performs immediate
writes, drains segmented queues with C<writev>, and accounts for backpressure.
The class descriptor moves immutable callbacks and parser configuration out of
each connection. Perl is entered for semantic C<on_data> or C<on_message>
delivery and lifecycle policy.

=cut
