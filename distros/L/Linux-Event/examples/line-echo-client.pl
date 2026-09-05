#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

{
    package EchoClient;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";

    sub on_ready ($stream) {
        $stream->send($stream->data->{message});
    }

    sub on_message ($stream, $line) {
        say $line;
        $stream->close;
        $stream->loop->stop;
    }

    sub on_error ($stream, $error) {
        warn "$error\n";
        $stream->loop->stop;
    }
}

use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
my $client = $loop->add(EchoClient->connect(
    host => '127.0.0.1',
    port => $ARGV[0] // 9999,
    data => { message => $ARGV[1] // 'hello' },
));
$loop->run;
