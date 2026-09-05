#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

{
    package EchoSocket;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";

    sub on_message ($stream, $line) { $stream->send($line) }
}

use Linux::Event::IO::Sock::Listener;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
my $server = $loop->add(Linux::Event::IO::Sock::Listener->new(
    stream_class => 'EchoSocket',
    host => '0.0.0.0',
    port => $ARGV[0] // 9999,
));
say "echo server listening on port " . $server->port;
$loop->run;
