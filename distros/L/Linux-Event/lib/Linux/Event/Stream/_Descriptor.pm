package Linux::Event::Stream::_Descriptor;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use mro ();

use Linux::Event::_SocketConfig ();

# Private descriptor storage is isolated here so Stream.pm can remain the
# readable connection-lifecycle implementation.
my %FRAMER_DEFINITION;
my %TLS_DEFINITION;
my %CLASS_DESCRIPTOR;

sub declare_framer ($base, $target, $definition) {
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

sub declare_tls ($base, $target, $definition) {
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
        read_batch_bytes =>         0,
        message_batch_size =>       0,
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
    croak "$class read_batch_bytes must be a non-negative integer"
        if $option{read_batch_bytes} !~ /\A\d+\z/;
    croak "$class message_batch_size must be a non-negative integer"
        if $option{message_batch_size} !~ /\A\d+\z/;
    croak "$class max_buffer must be a positive integer"
        if $option{max_buffer} !~ /\A\d+\z/ || $option{max_buffer} <= 0;
    for my $name (qw(idle_timeout read_timeout write_timeout)) {
        $option{$name} = Linux::Event::Stream::_timeout_value(
            $class, $name, $option{$name},
        );
    }
    for my $name (Linux::Event::_SocketConfig::names()) {
        $option{$name} = Linux::Event::_SocketConfig::normalize(
            $class, $name, $option{$name},
        ) if defined $option{$name};
        delete $option{$name} if !defined $option{$name};
    }

    return \%option;
}

sub for_class ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Stream is a base class; construct a Stream subclass'
        if $class eq 'Linux::Event::Stream';
    croak "$class is not a Linux::Event::Stream subclass"
        if !$class->isa('Linux::Event::Stream');

    my $framer = _framer_for($class);
    my $tls = _tls_for($class);
    my $option = _stream_options_for($class);
    my %callback = map { $_ => scalar $class->can($_) }
        qw(on_data on_message on_messages on_drain on_eof on_error on_close
           on_ready on_transport_ready configure_socket);

    if ($framer) {
        croak "$class read_batch_bytes is available only to raw Streams"
            if $option->{read_batch_bytes};
        croak "$class cannot define on_data() when it declares a framer"
            if $callback{on_data};
        if ($option->{message_batch_size}) {
            croak "$class enables message_batch_size but does not define on_messages()"
                if !$callback{on_messages};
            croak "$class cannot define both on_message() and on_messages()"
                if $callback{on_message};
        } else {
            croak "$class defines on_messages() without enabling message_batch_size"
                if $callback{on_messages};
            croak "$class declares a framer but does not define on_message()"
                if !$callback{on_message};
        }
    } else {
        croak "$class has no framer and must define on_data()"
            if !$callback{on_data};
        croak "$class defines on_message() but does not declare a framer"
            if $callback{on_message};
        croak "$class defines on_messages() but does not declare a framer"
            if $callback{on_messages};
        croak "$class message_batch_size is available only to framed Streams"
            if $option->{message_batch_size};
    }

    my $native = $framer ? { %{ $framer->{native} } } : { read_mode => 0 };

    my $xs = Linux::Event::Stream::XSDescriptor->new(
        $option->{read_size},
        $option->{read_batch_bytes},
        $option->{message_batch_size},
        $option->{high_watermark},
        $option->{low_watermark},
        $option->{max_pending_bytes},
        $option->{max_buffer},
        $native->{read_mode},
        $callback{on_data},
        $callback{on_message},
        $callback{on_messages},
        $callback{on_drain} ? \&Linux::Event::Stream::_xs_drain : undef,
        \&Linux::Event::Stream::_xs_read_eof,
        \&Linux::Event::Stream::_xs_read_error,
        \&Linux::Event::Stream::_xs_write_error,
        \&Linux::Event::Stream::_xs_output_limit,
        \&Linux::Event::Stream::_xs_write_empty,
        \&Linux::Event::Stream::_xs_framing_error,
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

sub clear_cache () {
    %CLASS_DESCRIPTOR = ();
    return;
}

1;
