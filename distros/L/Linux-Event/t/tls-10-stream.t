use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use FindBin qw($Bin);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::TLS;

{
    package T::TLSClient;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_transport_ready ($stream) {
        $stream->data->{client_ready}++;
        $stream->write('ping');
    }
    sub on_data ($stream, $bytes) {
        $stream->data->{client_input} .= $bytes;
        $stream->loop->stop if $stream->data->{client_input} eq 'pong';
    }
    sub on_error ($stream, $error) {
        $stream->data->{errors} .= "$error";
        $stream->data->{client_error} = $error;
        $stream->loop->stop;
    }
}

{
    package T::TLSServer;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_transport_ready ($stream) { $stream->data->{server_ready}++ }
    sub on_data ($stream, $bytes) {
        $stream->data->{server_input} .= $bytes;
        $stream->write('pong') if $stream->data->{server_input} eq 'ping';
    }
    sub on_eof ($stream) {
        $stream->data->{server_eof}++;
        $stream->loop->stop;
    }
    sub on_error ($stream, $error) {
        $stream->data->{errors} .= "$error";
        $stream->data->{server_error} = $error;
        $stream->loop->stop;
    }
}

socketpair(my $client_fh, my $server_fh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";

my $loop = Linux::Event::Loop->new;
my $state = { client_input => '', server_input => '', errors => '' };
my $cert = "$Bin/tls-certs/server-cert.pem";
my $key = "$Bin/tls-certs/server-key.pem";

my $client_tls = Linux::Event::TLS->client(
    server_name => 'localhost',
    ca_file     => $cert,
    alpn        => ['les-test/1'],
);
my $server_tls = Linux::Event::TLS->server(
    cert_file => $cert,
    key_file  => $key,
    alpn      => ['les-test/1'],
);

my $server = T::TLSServer->new(
    loop => $loop, fh => $server_fh, data => $state, transport => $server_tls,
);
my $client = T::TLSClient->new(
    loop => $loop, fh => $client_fh, data => $state, transport => $client_tls,
);

is($client->transport_name, 'tls', 'client reports TLS transport');
is($server->transport_name, 'tls', 'server reports TLS transport');
ok(!$client->is_transport_ready, 'client handshake starts asynchronously');

$loop->run_for(2);
is($state->{errors}, '', 'handshake and exchange have no TLS errors');
is($state->{client_ready}, 1, 'client ready callback fires exactly once');
is($state->{server_ready}, 1, 'server ready callback fires exactly once');
is($state->{server_input}, 'ping', 'server receives decrypted bytes');
is($state->{client_input}, 'pong', 'client receives decrypted bytes');
is($client_tls->selected_alpn, 'les-test/1', 'client exposes selected ALPN');
is($server_tls->selected_alpn, 'les-test/1', 'server exposes selected ALPN');
like($client_tls->protocol, qr/^TLSv1\.[23]$/, 'protocol is available');
ok(defined $client_tls->cipher, 'cipher is available');

my $detach_error = eval { $client->detach; 1 } ? '' : $@;
like($detach_error, qr/cannot detach a non-plain transport/,
    'encrypted descriptor cannot be detached as plaintext');

$client->end;
$loop->run_for(2);
is($state->{server_eof}, 1, 'end sends TLS close_notify');
ok($client->is_write_ended, 'client writable side ends after close_notify');
is($server_tls->stats->{clean_eof_count}, 1,
    'peer close_notify is counted as clean EOF');
ok($client_tls->stats->{shutdown_calls} >= 1,
    'local TLS shutdown calls are counted');

$client->close;
$server->close;

socketpair(my $bad_client_fh, my $bad_server_fh,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $bad_loop = Linux::Event::Loop->new;
my $bad_state = { client_input => '', server_input => '', errors => '' };
my $bad_server = T::TLSServer->new(
    loop => $bad_loop,
    fh => $bad_server_fh,
    data => $bad_state,
    transport => Linux::Event::TLS->server(
        cert_file => $cert, key_file => $key,
    ),
);
my $bad_client = T::TLSClient->new(
    loop => $bad_loop,
    fh => $bad_client_fh,
    data => $bad_state,
    transport => Linux::Event::TLS->client(
        server_name => 'not-localhost.example', ca_file => $cert,
    ),
);
$bad_loop->run_for(2);
isa_ok($bad_state->{client_error}, 'Linux::Event::Error');
is($bad_state->{client_error}->type, 'tls',
    'verification failure is a typed TLS error');
is($bad_state->{client_error}->operation, 'handshake',
    'verification failure identifies handshake operation');
like($bad_state->{client_error}->message, qr/certificate verify failed/i,
    'verification failure preserves OpenSSL diagnostic');
$bad_client->close;
$bad_server->close;

socketpair(my $paused_client_fh, my $paused_server_fh,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $paused_loop = Linux::Event::Loop->new;
my $paused_state = { client_input => '', server_input => '', errors => '' };
my $paused_server = T::TLSServer->new(
    loop => $paused_loop,
    fh => $paused_server_fh,
    data => $paused_state,
    transport => Linux::Event::TLS->server(
        cert_file => $cert, key_file => $key,
    ),
);
my $paused_client = T::TLSClient->new(
    loop => $paused_loop,
    fh => $paused_client_fh,
    data => $paused_state,
    transport => Linux::Event::TLS->client(
        server_name => 'localhost', ca_file => $cert,
    ),
);
$paused_client->pause_read;
$paused_loop->run_for(0.05);
ok($paused_client->is_transport_ready,
    'TLS handshake progresses while application reads are paused');
is($paused_state->{client_input}, '',
    'paused Stream withholds decrypted application input');
$paused_client->resume_read;
$paused_loop->run_for(2);
is($paused_state->{client_input}, 'pong',
    'resumed Stream receives TLS application input');
is($paused_state->{errors}, '', 'paused TLS path has no errors');
$paused_client->close;
$paused_server->close;

done_testing;
