use v5.36;
use strict;
use warnings;
use Test::More;
use POSIX qw(_exit);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use FindBin qw($Bin);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::TLS;

{
    package T::TLSSigpipeClient;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_transport_ready ($stream) { $stream->write('ping') }
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
    package T::TLSSigpipeServer;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) { $stream->write('pong') }
    sub on_error ($stream, $error) {
        $stream->data->{server_error} = $error;
        $stream->loop->stop;
    }
}

my $pid = fork;
die "fork: $!" if !defined $pid;

if ($pid == 0) {
    $SIG{PIPE} = 'DEFAULT';
    socketpair(my $client_fh, my $server_fh,
        AF_UNIX, SOCK_STREAM, PF_UNSPEC) or _exit(2);

    my $loop = Linux::Event::Loop->new;
    my $state = { input => '' };
    my $cert = "$Bin/tls-certs/server-cert.pem";
    my $key = "$Bin/tls-certs/server-key.pem";
    my $server = T::TLSSigpipeServer->new(
        loop => $loop,
        fh => $server_fh,
        data => $state,
        transport => Linux::Event::TLS->server(
            cert_file => $cert,
            key_file => $key,
        ),
    );
    my $client = T::TLSSigpipeClient->new(
        loop => $loop,
        fh => $client_fh,
        data => $state,
        transport => Linux::Event::TLS->client(
            server_name => 'localhost',
            ca_file => $cert,
        ),
    );

    $loop->run_for(1);
    _exit(3) if $state->{input} ne 'pong';
    $server->close;
    $client->write('write-after-peer-close');
    $loop->run_for(0.1) if !$client->is_closed;
    _exit(0);
}

waitpid($pid, 0);
is($?, 0, 'abrupt TLS peer close cannot terminate the process with SIGPIPE');

done_testing;
