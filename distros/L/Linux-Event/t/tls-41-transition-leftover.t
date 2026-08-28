use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;
use Linux::Event::TLS;

{
    package T::TLSUpgradeServer;
    use parent 'Linux::Event::Stream';
    sub on_ready ($stream) {
        $stream->write(
            "HTTP/1.1 101 Switching Protocols\r\n"
            . "Upgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
            . "\x81\x02hi"
        );
    }
    sub on_data ($stream, $bytes) { return }
    sub on_error ($stream, $error) {
        $stream->data->{error} = "$error";
        $stream->loop->stop;
    }
}

{
    package T::TLSUpgradeClient;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{http} .= $bytes;
        my $marker = index($state->{http}, "\r\n\r\n");
        return if $marker < 0;
        my $tail = substr($state->{http}, $marker + 4);
        $state->{header} = substr($state->{http}, 0, $marker + 4);
        $state->{tail_at_transition} = length($tail);
        $stream->transition_to('T::TLSWebSocketBytes', input => $tail);
    }
    sub on_error ($stream, $error) {
        $stream->data->{error} = "$error";
        $stream->loop->stop;
    }
}

{
    package T::TLSWebSocketBytes;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) {
        $stream->data->{frame} .= $bytes;
        $stream->loop->stop if length($stream->data->{frame}) >= 4;
    }
    sub on_error ($stream, $error) {
        $stream->data->{error} = "$error";
        $stream->loop->stop;
    }
}

socketpair(my $client_fh, my $server_fh,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { http => '', frame => '', error => '' };
my $cert = "$Bin/tls-certs/server-cert.pem";
my $key = "$Bin/tls-certs/server-key.pem";

my $server = T::TLSUpgradeServer->new(
    loop => $loop, fh => $server_fh, data => $state,
    transport => Linux::Event::TLS->server(
        cert_file => $cert, key_file => $key,
    ),
);
my $client = T::TLSUpgradeClient->new(
    loop => $loop, fh => $client_fh, data => $state,
    transport => Linux::Event::TLS->client(
        server_name => 'localhost', ca_file => $cert,
    ),
);

$loop->run_for(2);
is($state->{error}, '', 'TLS Upgrade transition has no error');
like($state->{header}, qr/\AHTTP\/1\.1 101 /,
    'client receives complete Upgrade response');
is($state->{tail_at_transition}, 4,
    'first protocol frame shares the decrypted read containing the headers');
isa_ok($client, 'T::TLSWebSocketBytes');
is($client->transport_name, 'tls', 'transition retains TLS transport');
is($state->{frame}, "\x81\x02hi",
    'leftover encrypted application bytes reach target protocol intact');

$client->close;
$server->close;
done_testing;
