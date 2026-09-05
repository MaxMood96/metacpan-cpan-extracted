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
    package T::TLSEstablishedDeadline;
    use parent 'Linux::Event::IO::Sock::Stream';

    sub on_transport_ready ($stream) {
        $stream->data->{ready}++;
        return;
    }

    sub on_data ($stream, $bytes) {
        $stream->data->{input} .= $bytes;
        return;
    }

    sub on_error ($stream, $error) {
        $stream->data->{error} = $error;
        return;
    }
}

my $cert = "$Bin/tls-certs/server-cert.pem";
my $key = "$Bin/tls-certs/server-key.pem";

{
    socketpair(my $client_fh, my $idle_peer, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair: $!";
    my $loop = Linux::Event::Loop->new;
    my $state = { ready => 0, input => '' };
    my $stream = T::TLSEstablishedDeadline->new(
        loop => $loop,
        fh => $client_fh,
        data => $state,
        deadline => { after => 0.01, operation => 'session' },
        transport => Linux::Event::TLS->client(
            server_name => 'localhost',
            verify => 0,
            handshake_timeout => 0.04,
        ),
    );
    is $loop->stats->{active_timers}, 0,
        'established operation deadline is dormant during TLS handshake';
    $loop->run_for(0.15);
    isa_ok $state->{error}, 'Linux::Event::Error';
    is $state->{error}->type, 'tls',
        'TLS handshake deadline owns pre-establishment timeout';
    is $state->{error}->operation, 'handshake',
        'operation deadline does not preempt handshake deadline';
    is $state->{ready}, 0, 'stalled TLS transport never became established';
    ok $stream->is_closed, 'handshake failure closes Stream';
    close $idle_peer;
}

{
    socketpair(my $client_fh, my $server_fh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair: $!";
    my $loop = Linux::Event::Loop->new;
    my $client_state = { ready => 0, input => '' };
    my $server_state = { ready => 0, input => '' };

    my $server = T::TLSEstablishedDeadline->new(
        loop => $loop,
        fh => $server_fh,
        data => $server_state,
        transport => Linux::Event::TLS->server(
            cert_file => $cert,
            key_file => $key,
        ),
    );
    my $client = T::TLSEstablishedDeadline->new(
        loop => $loop,
        fh => $client_fh,
        data => $client_state,
        idle_timeout => 0.04,
        transport => Linux::Event::TLS->client(
            server_name => 'localhost',
            ca_file => $cert,
        ),
    );

    is $loop->stats->{active_timers}, 0,
        'TLS idle deadline is dormant before transport readiness';
    $loop->run_for(0.25);
    is $client_state->{ready}, 1, 'client TLS transport became ready';
    is $server_state->{ready}, 1, 'server TLS transport became ready';
    isa_ok $client_state->{error}, 'Linux::Event::Error';
    is $client_state->{error}->type, 'timeout',
        'post-handshake idle expiration is a Stream timeout';
    is $client_state->{error}->operation, 'idle',
        'post-handshake idle expiration identifies idle policy';
    ok $client->is_closed, 'TLS Stream closes on established idle timeout';
    is $loop->stats->{timerfd_create_calls}, 1,
        'TLS established deadline uses shared Loop scheduler';
    $server->close;
}

done_testing;
