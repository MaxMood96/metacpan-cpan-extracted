#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

{
    package EchoStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";

    sub on_message ($stream, $line) { $stream->send($line) }
}

use Linux::Event::Listener;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
my $server = $loop->add(Linux::Event::Listener->new(
    stream_class => 'EchoStream',
    host => '0.0.0.0',
    port => $ARGV[0] // 9999,
));
say "echo server listening on port " . $server->port;
$loop->run;
