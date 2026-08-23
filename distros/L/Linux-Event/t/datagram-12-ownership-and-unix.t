use v5.36;
use strict;
use warnings;

use File::Temp qw(tempdir);
use Socket qw(
    AF_INET INADDR_ANY SOCK_DGRAM
    inet_aton pack_sockaddr_in unpack_sockaddr_in
);
use Test::More;

use Linux::Event::Datagram;
use Linux::Event::Loop;

our (@ERRORS, $CLOSES);
$CLOSES = 0;

{
    package T::OwnedDatagram;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($self, $payload, $peer) { }
    sub on_error ($self, $error) {
        push @main::ERRORS, [$error, !!$self->loop];
    }
    sub on_close ($self) { $main::CLOSES++ }
}

sub exception ($code) {
    local $@;
    return eval { $code->(); 1 } ? '' : "$@";
}

like(exception(sub { T::OwnedDatagram->new(
    host => '127.0.0.1', # required
    port => 0,           # required
    unlink => 0,         # invalid even though false
) }), qr/options not valid for UDP: unlink/,
    'UDP rejects an explicitly supplied Unix-only false option');

like(exception(sub { T::OwnedDatagram->connect(
    unix     => '/tmp/linux-event-unused.sock', # required
    broadcast => 0,                             # invalid even though false
) }), qr/options not valid for Unix datagrams: broadcast/,
    'Unix mode rejects an explicitly supplied Internet-only false option');

like(exception(sub { T::OwnedDatagram->connect(
    unix       => '/tmp/linux-event-unused.sock', # required peer path
    permissions => 0600,                          # invalid without local_unix
) }), qr/options not valid for Unix datagrams: permissions/,
    'connected Unix mode rejects local-path policy without local_unix');

like(exception(sub { T::OwnedDatagram->new(
    host   => '127.0.0.1', # required
    port   => 0,           # required
    v6only => 0,           # invalid for IPv4
) }), qr/v6only requires an IPv6 bind address/,
    'IPv4 bind rejects the IPv6-only socket option');

socket(my $borrowed_fh, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
bind($borrowed_fh, pack_sockaddr_in(0, inet_aton('127.0.0.1')))
    or die "bind: $!";
my $borrowed = T::OwnedDatagram->new(
    fh          => $borrowed_fh, # required
    owns_socket => 0,            # default
);
$borrowed->close;
ok(defined fileno($borrowed_fh),
    'closing a borrowed adopted Datagram leaves caller handle open');
close $borrowed_fh;

socket(my $owned_fh, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
bind($owned_fh, pack_sockaddr_in(0, inet_aton('127.0.0.1')))
    or die "bind: $!";
my $owned = T::OwnedDatagram->new(
    fh          => $owned_fh, # required
    owns_socket => 1,         # optional ownership transfer
);
$owned->close;
ok(!defined fileno($owned_fh),
    'closing an owned adopted Datagram closes caller handle');

socket(my $detached_fh, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
bind($detached_fh, pack_sockaddr_in(0, inet_aton('127.0.0.1')))
    or die "bind: $!";
my $detached = T::OwnedDatagram->new(
    fh          => $detached_fh, # required
    owns_socket => 1,            # optional ownership transfer
);
my $close_count = $CLOSES;
my $returned = $detached->detach;
is(fileno($returned), fileno($detached_fh),
    'detach returns the still-open adopted handle');
is($CLOSES, $close_count, 'detach does not call on_close');
close $returned;

@ERRORS = ();
my $loop = Linux::Event::Loop->new;
my $mismatch = $loop->add(T::OwnedDatagram->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_host => '::1',       # optional
));
is($mismatch->state, 'failed',
    'numeric local-family mismatch fails during attachment');
is($ERRORS[0][0]->type, 'socket_configuration',
    'Datagram local-family mismatch is typed');
is($ERRORS[0][0]->option, 'local_host',
    'Datagram mismatch identifies local_host');
ok($ERRORS[0][1], 'on_error retains Loop during terminal notification');
is($mismatch->loop, undef, 'failed Datagram releases Loop after on_error');

socket(my $occupied_udp, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
bind($occupied_udp, pack_sockaddr_in(0, INADDR_ANY)) or die "bind: $!";
my ($occupied_udp_port) = unpack_sockaddr_in(getsockname($occupied_udp));
@ERRORS = ();
my $collision_loop = Linux::Event::Loop->new;
my $collision = $collision_loop->add(T::OwnedDatagram->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_port => $occupied_udp_port, # optional source port
));
is($collision->state, 'failed',
    'Datagram local port collision fails during attachment');
is($ERRORS[0][0]->type, 'socket_configuration',
    'Datagram local bind syscall failure is typed');
is($ERRORS[0][0]->option, 'local_port',
    'Datagram local bind syscall failure identifies local_port');
close $occupied_udp;

our ($CONFIG_CALLS, $CONFIG_ERROR) = (0, undef);
{
    package T::ConfiguredDatagram;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($self, $payload, $peer) { }
    sub configure_socket ($self, $fh, $role, $address) {
        $main::CONFIG_CALLS++;
        die "policy rejected $role\n";
    }
    sub on_error ($self, $error) {
        $main::CONFIG_ERROR = $error;
        $self->loop->stop;
    }
}

my $config_loop = Linux::Event::Loop->new;
my $configured = $config_loop->add(T::ConfiguredDatagram->connect(
    host => 'localhost', # required
    port => 9,           # required
));
$config_loop->run;
is($CONFIG_CALLS, 1,
    'terminal socket policy failure does not try unrelated DNS candidates');
is($CONFIG_ERROR->type, 'socket_configuration',
    'Datagram configure_socket failure is typed');
is($CONFIG_ERROR->operation, 'configure_socket',
    'Datagram configuration failure identifies the hook');
is($configured->state, 'failed',
    'Datagram configuration failure is terminal');

subtest 'connected Unix close preserves peer path' => sub {
    my $directory = tempdir(CLEANUP => 1);
    my $server_path = "$directory/server.sock";
    my $client_path = "$directory/client.sock";
    my $server = eval { T::OwnedDatagram->new(unix => $server_path) };
    plan skip_all => "Unix datagram sockets unavailable: $@" if !$server;

    my $unix_loop = Linux::Event::Loop->new;
    $unix_loop->add($server);
    my $client = $unix_loop->add(T::OwnedDatagram->connect(
        unix       => $server_path, # required peer path
        local_unix => $client_path, # optional reply path
    ));
    ok($client->is_active, 'connected Unix Datagram is active');
    ok(-S $server_path, 'server socket path exists before client close');
    ok(-S $client_path, 'client local socket path exists while active');
    $client->close;
    ok(-S $server_path, 'client close never unlinks peer server path');
    ok(!-e $client_path, 'client close removes its owned local path');
    $server->close;
    ok(!-e $server_path, 'server close removes its owned bind path');
};

subtest 'failed Unix construction leaves no path' => sub {
    my $directory = tempdir(CLEANUP => 1);
    my $probe_path = "$directory/probe.sock";
    my $probe = eval { T::OwnedDatagram->new(unix => $probe_path) };
    plan skip_all => "Unix datagram sockets unavailable: $@" if !$probe;
    $probe->close;

    my $failed_path = "$directory/failed.sock";
    like(exception(sub { T::OwnedDatagram->new(
        unix     => $failed_path, # required
        surprise => 1,            # invalid
    ) }), qr/unknown options: surprise/,
        'unknown option is rejected before creating a Unix socket');
    ok(!-e $failed_path,
        'failed constructor does not leave a Unix socket path');

    my $owned_path = "$directory/owned.sock";
    like(exception(sub { T::OwnedDatagram->new(
        unix        => $owned_path, # required
        owns_socket => 1,           # invalid without fh
    ) }), qr/owns_socket/,
        'ownership transfer option is rejected before Unix socket creation');
    ok(!-e $owned_path,
        'invalid ownership option does not leave a Unix socket path');
};

done_testing;
