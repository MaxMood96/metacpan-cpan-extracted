package Linux::Event::_Socket::Descriptor;
use v5.36;
use strict;
use warnings;


use Carp qw(croak);
use mro ();
use Linux::Event::_SocketConfig ();

my %TLS_DEFINITION;
my %CLASS_DESCRIPTOR;

sub declare_tls ($base, $target, $definition) {
    croak 'TLS may be declared only for a Linux::Event stream-socket subclass'
        if $target eq $base || !$target->isa($base);
    croak "$target already has a stream-socket descriptor"
        if exists $CLASS_DESCRIPTOR{$target};
    croak "$target already declares TLS" if exists $TLS_DEFINITION{$target};
    croak 'TLS declaration must be a hash reference'
        if ref($definition) ne 'HASH';
    $TLS_DEFINITION{$target} = $definition;
    return;
}

sub _tls_for ($class) {
    for my $package (@{ mro::get_linear_isa($class) }) {
        return $TLS_DEFINITION{$package} if exists $TLS_DEFINITION{$package};
    }
    return undef;
}

sub for_class ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::_Socket::Stream is a private implementation base; subclass Linux::Event::IO::Sock::Stream'
        if $class eq 'Linux::Event::_Socket::Stream';
    croak "$class is not a Linux::Event stream-socket class"
        if !$class->isa('Linux::Event::_Socket::Stream');

    my %option = map { $_ => undef } Linux::Event::_SocketConfig::names();
    if (my $configure = $class->can('socket_options')) {
        my @configured = $configure->($class);
        my %configured;
        if (@configured == 1 && ref($configured[0]) eq 'HASH') {
            %configured = %{ $configured[0] };
        } else {
            croak "$class socket_options() returned an odd option list"
                if @configured % 2;
            %configured = @configured;
        }
        my @unknown = grep { !exists $option{$_} } keys %configured;
        croak "$class socket_options() returned unknown options: "
            . join(', ', sort @unknown) if @unknown;
        @option{keys %configured} = values %configured;
    }
    for my $name (keys %option) {
        if (defined $option{$name}) {
            $option{$name} = Linux::Event::_SocketConfig::normalize(
                $class, $name, $option{$name},
            );
        } else {
            delete $option{$name};
        }
    }
    return $CLASS_DESCRIPTOR{$class} = {
        options => \%option,
        tls => _tls_for($class),
        configure_socket => scalar $class->can('configure_socket'),
    };
}

sub clear_cache () { %CLASS_DESCRIPTOR = (); return }

1;
