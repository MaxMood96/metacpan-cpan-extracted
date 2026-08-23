use v5.36;
use strict;
use warnings;

use Test::More;
use Scalar::Util qw(blessed);

use Linux::Event::Datagram;
use Linux::Event::Loop;

sub exception ($code) {
    local $@;
    return eval { $code->(); 1 } ? '' : "$@";
}

like(exception(sub { Linux::Event::Datagram->new }), qr/abstract base class/,
    'base Datagram class is abstract');

{
    package T::Datagram::Missing;
    use parent 'Linux::Event::Datagram';
}
like(exception(sub { T::Datagram::Missing->new(host => '127.0.0.1', port => 0) }),
    qr/must define on_datagram/, 'on_datagram is required');

{
    package T::Datagram::Basic;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($self, $payload, $peer) { }
}

like(exception(sub { T::Datagram::Basic->new(host => '127.0.0.1') }),
    qr/port must be an integer/, 'UDP bind requires port');
like(exception(sub { T::Datagram::Basic->new(
    host => "127.0.0.1\0.invalid", port => 0,
) }), qr/without NUL bytes/, 'bound host containing a NUL byte is rejected');
like(exception(sub { T::Datagram::Basic->new(
    unix => "/tmp/linux-event\0.sock",
) }), qr/without NUL bytes/, 'bound Unix path containing a NUL byte is rejected');
like(exception(sub { T::Datagram::Basic->new(
    host => '127.0.0.1', port => 0, edge_triggered => 1,
) }), qr/edge_triggered requires max_datagrams_per_tick => 0/,
    'edge triggering requires unlimited drain');
like(exception(sub { T::Datagram::Basic->connect(
    host => '127.0.0.1', port => 9, local_host => 'localhost',
) }), qr/local_host must be a numeric IPv4 or IPv6 address/,
    'local binding does not perform a second DNS lookup');
like(exception(sub { T::Datagram::Basic->connect(
    host => "127.0.0.1\0.invalid", port => 9,
) }), qr/without NUL bytes/, 'peer host containing a NUL byte is rejected');
like(exception(sub { T::Datagram::Basic->connect(
    unix => "/tmp/linux-event\0.sock",
) }), qr/without NUL bytes/, 'peer Unix path containing a NUL byte is rejected');
like(exception(sub { T::Datagram::Basic->connect(
    unix       => '/tmp/linux-event-peer.sock',
    local_unix => "/tmp/linux-event\0.sock",
) }), qr/without NUL bytes/,
    'local Unix path containing a NUL byte is rejected');
like(exception(sub { T::Datagram::Basic->connect(
    host => '127.0.0.1', port => 9, send_buffer => 2_147_483_648,
) }), qr/send_buffer must be at most 2147483647/,
    'integer socket options reject values that cannot fit the kernel ABI');
like(exception(sub { T::Datagram::Basic->new(
    host => '127.0.0.1', port => 0,
    max_pending_bytes => '99999999999999999999',
) }), qr/max_pending_bytes must be at most/,
    'Datagram queue limits must fit a native Perl integer');

our (@CONFIGURE_ROLES, $CONFIGURE_ADDRESS);
{
    package T::Datagram::Configured;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($self, $payload, $peer) { }
    sub configure_socket ($self, $fh, $role, $address) {
        push @main::CONFIGURE_ROLES, $role;
        $main::CONFIGURE_ADDRESS = $address;
    }
}
my $configured = T::Datagram::Configured->new(
    host => '127.0.0.1', # required
    port => 0,           # required
);
is_deeply(\@CONFIGURE_ROLES, ['bind'],
    'bound Datagram invokes configure_socket with bind role');
is($CONFIGURE_ADDRESS->port, $configured->local->port,
    'bound configure_socket receives the effective local Address');
$configured->close;

my $explicit_ephemeral = T::Datagram::Basic->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_port => 0,           # optional explicit ephemeral bind
);
ok($explicit_ephemeral->{local_bind},
    'explicit local_port zero retains the local-bind request');
$explicit_ephemeral->close;

my $socket = T::Datagram::Basic->new(
    host => '127.0.0.1', # required
    port => 0,           # required
);
like(exception(sub { $socket->send("\x{100}") }), qr/payload must be a byte string/,
    'Datagram rejects a wide-character payload before packet I/O');
is($socket->state, 'unattached', 'bound Datagram starts unattached');
is($socket->local->family, 'inet', 'bound Datagram has local Address');
cmp_ok($socket->local->port, '>', 0, 'port zero selects an ephemeral port');
ok(!$socket->is_connected, 'bound Datagram is unconnected');
my $loop = Linux::Event::Loop->new;
is($loop->add($socket), $socket, 'Loop add returns exact Datagram');
ok($socket->is_active, 'Datagram becomes active');
is($socket->broadcast(1), 1, 'broadcast can be enabled live');
is($socket->broadcast(0), 0, 'broadcast can be disabled live');
cmp_ok($socket->send_buffer(65_536), '>=', 65_536,
    'send buffer can be set live');
cmp_ok($socket->receive_buffer(65_536), '>=', 65_536,
    'receive buffer can be set live');
is($socket->pause_read, $socket, 'pause_read returns Datagram');
ok($socket->is_read_paused, 'read pause is observable');
is($socket->resume_read, $socket, 'resume_read returns Datagram');
ok(!$socket->is_read_paused, 'read resume is observable');
is($socket->close, $socket, 'close returns Datagram');
ok($socket->is_terminal, 'close is terminal');
is($socket->close, $socket, 'close is idempotent');

{
    package T::Datagram::BrokenLoop;
    sub new ($class) { bless {}, $class }
    sub add ($self, $object) { $object->_attach_to_loop($self) }
    sub watch ($self, @option) { die "synthetic Datagram watch failure\n" }
}

my $retry = T::Datagram::Basic->new(
    host => '127.0.0.1', # required
    port => 0,           # required
);
my $broken = T::Datagram::BrokenLoop->new;
my $attach_error = eval { $broken->add($retry); undef } // $@;
ok(blessed($attach_error) && $attach_error->isa('Linux::Event::Error'),
    'registration failure throws a structured Error');
is($attach_error->operation, 'watch',
    'registration failure identifies the watch operation');
is($retry->state, 'unattached',
    'registration failure restores the detached lifecycle');
ok(defined($retry->fd),
    'registration failure preserves the bound socket for retry');
is($loop->add($retry), $retry,
    'bound Datagram can attach after a registration failure');
$retry->close;

SKIP: {
    my $ipv6 = eval { T::Datagram::Basic->new(
        host   => '::1', # required
        port   => 0,     # required
        v6only => 1,     # optional
    ) };
    skip "IPv6 loopback unavailable: $@", 2 if !$ipv6;
    my $broadcast_error = eval { $ipv6->broadcast; undef } // $@;
    ok(blessed($broadcast_error)
        && $broadcast_error->isa('Linux::Event::Error'),
        'IPv6 broadcast access throws a structured Error');
    is($broadcast_error->option, 'broadcast',
        'IPv6 broadcast error identifies the option');
    $ipv6->close;
}

done_testing;
