use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX);

use Linux::Event::Error;
use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

{
    package T::ConnectProbeStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) { }
}

{
    package T::ConnectProbeTransport;
    sub _stream_transport_bind ($self, $fd) {
        die 'transport must not bind before a connection succeeds';
    }
}

my $loop = Linux::Event::Loop->new;

like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => 'not-a-loop', sockaddr => '', family => AF_UNIX,
    );
}), qr/loop must be an object/, 'loop must provide the reactor API');
like(exception(sub { T::ConnectProbeStream->connect(loop => $loop) }),
    qr/exactly one address mode/, 'one address mode is required');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, host => '127.0.0.1', port => 1,
        unix => '/tmp/not-used',
    );
}), qr/exactly one address mode/, 'mixed address modes are rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(loop => $loop, host => '', port => 1);
}), qr/non-empty string/, 'empty host is rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, host => "127.0.0.1\0.invalid", port => 1,
    );
}), qr/without NUL bytes/, 'host containing a NUL byte is rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, unix => "/tmp/linux-event\0.sock",
    );
}), qr/without NUL bytes/, 'Unix path containing a NUL byte is rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, host => '127.0.0.1', port => 70_000,
    );
}), qr/between 0 and 65535/, 'out-of-range port is rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, host => '127.0.0.1', port => 1,
        local_port => undef,
    );
}), qr/local_port must be an integer/,
    'explicit undefined local port is rejected cleanly');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, host => '127.0.0.1', port => 1,
        timeout => '99999999999999999999999999999999999999999999999999',
    );
}), qr/(?:finite number|supported timer range)/,
    'connection timeout cannot overflow native timer conversion');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, unix => '/tmp/not-used', timeout => -1,
    );
}), qr/non-negative number/, 'negative timeout is rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        loop => $loop, unix => '/tmp/not-used', surprise => 1,
    );
}), qr/unknown options: surprise/, 'unknown options are rejected');
like(exception(sub {
    T::ConnectProbeStream->connect(
        host => '127.0.0.1', port => 1, transport => {},
    );
}), qr/transport must be an object implementing _stream_transport_bind/,
    'public connect transport receives a public validation error');
my $transport = bless {}, 'T::ConnectProbeTransport';
my $pending = T::ConnectProbeStream->connect(
    host => '127.0.0.1', port => 1, transport => $transport,
);
is($pending->transport, $transport,
    'connect retains an explicit public transport provider');
$pending->close;

my $error = Linux::Event::Error->new(
    type      => 'connect',
    operation => 'connect',
    errno     => 111,
    message   => 'Connection refused',
    host      => '127.0.0.1',
    port      => 9,
    attempts  => 2,
);
is($error->type, 'connect', 'Error exposes type');
is($error->host, '127.0.0.1', 'Error exposes host');
is($error->attempts, 2, 'Error exposes attempt count');
is("$error", 'connect: Connection refused (errno=111)',
    'Error stringifies with operation and errno');

done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
