use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use FindBin qw($Bin);

use Linux::Event::Loop;
use Linux::Event::Stream;
use Linux::Event::TLS;

{
    package T::TLSDeadline;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) {
        $stream->data->{error} = $error;
        $stream->loop->stop;
    }
}

{
    package T::TLSProbeClient;
    use parent 'Linux::Event::Stream';
    sub on_transport_ready ($stream) {
        $stream->data->{client_ready}++;
        $stream->write('ping');
    }
    sub on_data ($stream, $bytes) {
        $stream->data->{input} .= $bytes;
        $stream->loop->stop if $stream->data->{input} eq 'pong';
    }
    sub on_error ($stream, $error) {
        $stream->data->{client_error} = $error;
        $stream->loop->stop;
    }
}

{
    package T::TLSProbeServer;
    use parent 'Linux::Event::Stream';
    sub on_transport_ready ($stream) { $stream->data->{server_ready}++ }
    sub on_data ($stream, $bytes) { $stream->write('pong') }
    sub on_error ($stream, $error) {
        $stream->data->{server_error} = $error;
        $stream->loop->stop;
    }
}

my $cert = "$Bin/tls-certs/server-cert.pem";
my $key = "$Bin/tls-certs/server-key.pem";

socketpair(my $timeout_fh, my $idle_peer, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $timeout_loop = Linux::Event::Loop->new;
my $timeout_state = {};
my $timeout_tls = Linux::Event::TLS->client(
    server_name       => 'localhost',
    verify            => 0,
    handshake_timeout => 0.02,
);
my $timeout_stream = T::TLSDeadline->new(
    loop => $timeout_loop,
    fh => $timeout_fh,
    data => $timeout_state,
    transport => $timeout_tls,
);
$timeout_loop->run_for(0.5);
isa_ok($timeout_state->{error}, 'Linux::Event::Error');
is($timeout_state->{error}->type, 'tls', 'handshake timeout is a TLS error');
is($timeout_state->{error}->operation, 'handshake',
    'handshake timeout identifies its operation');
is($timeout_state->{error}->message, 'TLS handshake timed out',
    'handshake timeout has a stable diagnostic');
is($timeout_tls->stats->{handshake_timeout_count}, 1,
    'handshake timeout is counted natively');
ok($timeout_stream->is_closed, 'handshake timeout closes the Stream');
close $idle_peer;

socketpair(my $shutdown_fh, my $shutdown_idle_peer,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $shutdown_loop = Linux::Event::Loop->new;
my $shutdown_state = {};
my $shutdown_tls = Linux::Event::TLS->client(
    server_name       => 'localhost',
    verify            => 0,
    handshake_timeout => 0,
    shutdown_timeout  => 0.02,
);
my $shutdown_stream = T::TLSDeadline->new(
    loop => $shutdown_loop,
    fh => $shutdown_fh,
    data => $shutdown_state,
    transport => $shutdown_tls,
);
$shutdown_stream->end;
$shutdown_loop->run_for(0.5);
isa_ok($shutdown_state->{error}, 'Linux::Event::Error');
is($shutdown_state->{error}->operation, 'shutdown',
    'shutdown timeout identifies its operation');
is($shutdown_state->{error}->message, 'TLS shutdown timed out',
    'shutdown timeout has a stable diagnostic');
is($shutdown_tls->stats->{shutdown_timeout_count}, 1,
    'shutdown timeout is counted natively');
close $shutdown_idle_peer;

socketpair(my $client_fh, my $server_fh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { input => '' };
my $client_tls = Linux::Event::TLS->client(
    server_name => 'localhost', ca_file => $cert,
);
my $server_tls = Linux::Event::TLS->server(
    cert_file => $cert, key_file => $key,
);
my $server = T::TLSProbeServer->new(
    loop => $loop, fh => $server_fh, data => $state, transport => $server_tls,
);
my $client = T::TLSProbeClient->new(
    loop => $loop, fh => $client_fh, data => $state, transport => $client_tls,
);
$loop->run_for(1);
is($state->{input}, 'pong', 'control exchange completes before abrupt close');
my $client_before = $client_tls->stats;
is($client_before->{handshake_successes}, 1, 'successful handshake is counted');
ok($client_before->{bytes_written} >= 4, 'TLS plaintext writes are counted');
ok($client_before->{bytes_read} >= 4, 'TLS plaintext reads are counted');

$server->close;
$loop->run_for(0.5);
isa_ok($state->{client_error}, 'Linux::Event::Error');
is($state->{client_error}->type, 'tls', 'unclean EOF is a TLS error');
is($state->{client_error}->operation, 'read',
    'unclean EOF identifies the read operation');
is($state->{client_error}->message,
    'TLS peer closed without close_notify',
    'unclean EOF is distinct from clean transport EOF');
is($client_tls->stats->{unclean_eof_count}, 1,
    'unclean EOF is counted natively');
$client->close;

done_testing;
