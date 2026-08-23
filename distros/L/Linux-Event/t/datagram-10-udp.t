use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Datagram;
use Linux::Event::Loop;

our (@SERVER_PACKETS, @CLIENT_PACKETS, @READY, @ERRORS);

{
    package T::Datagram::Server;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($self, $payload, $peer) {
        push @main::SERVER_PACKETS, [$payload, $peer->family, $peer->port];
        $self->send("reply:$payload", to => $peer);
    }
    sub on_error ($self, $error) { push @main::ERRORS, $error }
}

{
    package T::Datagram::Client;
    use parent 'Linux::Event::Datagram';
    sub on_ready ($self) {
        push @main::READY, $self->peer->family;
        $self->send('one');
        $self->send('two');
    }
    sub on_datagram ($self, $payload, $peer) {
        push @main::CLIENT_PACKETS, [$payload, $peer->family];
        $self->loop->stop if @main::CLIENT_PACKETS == 2;
    }
    sub on_error ($self, $error) { push @main::ERRORS, $error }
}

my $loop = Linux::Event::Loop->new;
my $server = $loop->add(T::Datagram::Server->new(
    host => '127.0.0.1', # required
    port => 0,           # required
));
my $client = $loop->add(T::Datagram::Client->connect(
    host       => 'localhost',   # required; resolved asynchronously
    port       => $server->local->port, # required
    local_host => '127.0.0.1',   # optional
    local_port => 0,             # optional
));

$loop->run;

is_deeply(\@READY, ['inet'], 'connected Datagram becomes ready after DNS');
is_deeply([map { $_->[0] } @SERVER_PACKETS], [qw(one two)],
    'server receives separate packet boundaries in order');
ok(!(grep { $_->[1] ne 'inet' || $_->[2] <= 0 } @SERVER_PACKETS),
    'server receives a complete peer Address for every packet');
is_deeply([map { $_->[0] } @CLIENT_PACKETS], ['reply:one', 'reply:two'],
    'unconnected replies reach connected client separately');
is_deeply(\@ERRORS, [], 'UDP exchange reports no errors');
ok($client->is_connected, 'client reports connected mode');
is($client->pending_datagrams, 0, 'output packet queue drains');
is($client->pending_bytes, 0, 'output byte queue drains');

$client->close;
$server->close;

done_testing;
