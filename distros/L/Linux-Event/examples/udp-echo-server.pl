#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event::Datagram;
use Linux::Event::Loop;

{
    package Example::UdpEcho;
    use parent 'Linux::Event::Datagram';

    sub on_datagram ($socket, $payload, $peer) {
        say 'received ' . length($payload) . ' bytes from '
            . $peer->host . ':' . $peer->port;
        $socket->send($payload, to => $peer);
    }

    sub on_error ($socket, $error) {
        warn "$error\n";
    }
}

my $host = shift(@ARGV) // '127.0.0.1';
my $port = shift(@ARGV) // 9999;
die "usage: $0 [numeric-host [port]]\n" if @ARGV;

my $loop = Linux::Event::Loop->new;
my $server = $loop->add(Example::UdpEcho->new(
    host      => $host,
    port      => $port,
    reuseaddr => 1,
));

say 'UDP echo server listening on '
    . $server->local->host . ':' . $server->local->port;
$loop->run;
