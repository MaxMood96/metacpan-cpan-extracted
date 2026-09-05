#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event::IO::Sock::Dgram;
use Linux::Event::Loop;

{
    package Example::UdpClient;
    use parent 'Linux::Event::IO::Sock::Dgram';

    sub on_ready ($socket) {
        $socket->send($socket->data->{message});
    }

    sub on_datagram ($socket, $payload, $peer) {
        say $payload;
        $socket->loop->stop;
        $socket->close;
    }

    sub on_error ($socket, $error) {
        $socket->loop->stop if $socket->loop;
        die "$error\n";
    }
}

my $host = shift(@ARGV) // '127.0.0.1';
my $port = shift(@ARGV) // 9999;
my $message = @ARGV ? join(' ', @ARGV) : 'hello from Linux::Event';

my $loop = Linux::Event::Loop->new;
$loop->add(Example::UdpClient->connect(
    host => $host,
    port => $port,
    data => { message => $message },
));
$loop->run;
