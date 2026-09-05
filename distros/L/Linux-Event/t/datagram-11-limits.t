use v5.36;
use strict;
use warnings;

use Socket qw(
    AF_INET SOCK_DGRAM
    inet_aton pack_sockaddr_in unpack_sockaddr_in
);
use Test::More;

use Linux::Event::IO::Sock::Dgram;
use Linux::Event::Loop;

our (@ERRORS, @PACKETS);

{
    package T::Datagram::LimitedClient;
    use parent 'Linux::Event::IO::Sock::Dgram';
    sub datagram_options ($class) {
        return max_pending_bytes => 4, max_pending_datagrams => 1;
    }
    sub on_datagram ($self, $payload, $peer) { push @main::PACKETS, $payload }
    sub on_error ($self, $error) { push @main::ERRORS, $error }
}

socket(my $receiver, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
bind($receiver, pack_sockaddr_in(0, inet_aton('127.0.0.1')))
    or die "bind: $!";
my ($port) = unpack_sockaddr_in(getsockname($receiver));

my $client = T::Datagram::LimitedClient->connect(
    host => '127.0.0.1', # required
    port => $port,        # required
);
is($client->send('four'), 1, 'packet may queue before attachment');
is($client->pending_datagrams, 1, 'pre-attachment packet count is retained');
is($client->send('x'), undef, 'hard packet limit rejects only new packet');
is($client->pending_datagrams, 1, 'rejected packet does not change queue');
is($ERRORS[-1]->type, 'output_limit', 'hard limit reports typed error');
is($ERRORS[-1]->pending_datagrams, 2,
    'hard limit reports attempted packet count');

my $loop = Linux::Event::Loop->new;
$loop->add($client);
$loop->run_once(1000);
my $peer = recv($receiver, my $payload, 64, 0);
ok(defined $peer, 'queued packet reaches peer after attachment');
is($payload, 'four', 'queued packet remains whole');
$client->close;
close $receiver;

@ERRORS = ();
{
    package T::Datagram::TinyServer;
    use parent 'Linux::Event::IO::Sock::Dgram';
    sub datagram_options ($class) { return max_datagram_size => 4 }
    sub on_datagram ($self, $payload, $peer) { push @main::PACKETS, $payload }
    sub on_error ($self, $error) {
        push @main::ERRORS, $error;
        $self->loop->stop;
    }
}

my $receive_loop = Linux::Event::Loop->new;
my $server = $receive_loop->add(T::Datagram::TinyServer->new(
    host => '127.0.0.1', # required
    port => 0,           # required
));
socket(my $sender, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
send($sender, '12345', 0, pack_sockaddr_in(
    $server->local->port, inet_aton('127.0.0.1'),
)) == 5 or die "send: $!";
$receive_loop->run;
is($ERRORS[0]->type, 'datagram_size', 'truncated packet reports typed error');
is($ERRORS[0]->datagram_size, 5, 'error retains original packet size');
is($ERRORS[0]->limit, 4, 'error retains configured packet limit');
is_deeply(\@PACKETS, [], 'oversized packet is never partially delivered');

$server->close;
close $sender;

done_testing;
