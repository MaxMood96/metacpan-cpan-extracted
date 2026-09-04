package Net::NATS2::URI;

use strict;
use warnings;

sub new {
    my $class = shift;
    return $class->parse(@_);
}

sub parse {
    my ($class, $value) = @_;
    return unless defined $value;

    my ($scheme, $authority) = $value =~ /\A(nats):\/\/([^\/?#]*)\z/i;
    return unless defined $scheme && length $authority;

    my ($userinfo, $host_port);
    $host_port = $authority;
    my $at = rindex($host_port, '@');
    if ($at >= 0) {
        $userinfo  = substr($host_port, 0, $at);
        $host_port = substr($host_port, $at + 1);
    }

    my ($host, $port);
    if ($host_port =~ /\A\[([^\]]+)\](?::(\d+))?\z/) {
        ($host, $port) = ($1, $2);
    }
    elsif ($host_port =~ /\A([^:]+)(?::(\d+))?\z/) {
        ($host, $port) = ($1, $2);
    }
    else {
        return;
    }

    my ($user, $password);
    if (defined $userinfo) {
        ($user, $password) = split /:/, $userinfo, 2;
        $user     = _percent_decode($user)     if defined $user;
        $password = _percent_decode($password) if defined $password;
    }

    return bless {
        as_string => $value,
        host      => $host,
        password  => $password,
        port      => $port,
        scheme    => lc $scheme,
        user      => $user,
    }, $class;
}

sub _percent_decode {
    my ($value) = @_;
    $value =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    return $value;
}

sub as_string { return $_[0]->{as_string}; }
sub host      { return $_[0]->{host}; }
sub password  { return $_[0]->{password}; }
sub port      { return $_[0]->{port}; }
sub scheme    { return $_[0]->{scheme}; }
sub user      { return $_[0]->{user}; }

1;
