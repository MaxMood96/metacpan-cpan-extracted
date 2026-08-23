use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC SHUT_WR);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::HalfCloseStream;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { $stream->data->{request} .= $bytes }
    sub on_eof ($stream) {
        my $state = $stream->data;
        $state->{eof_calls}++;
        Test::More::ok($stream->is_read_eof, 'read EOF state set before callback');
        Test::More::ok(!$stream->is_write_ended, 'writable side still open at peer EOF');
        Test::More::ok($stream->write('response'), 'write remains legal after peer EOF');
        $stream->end;
    }
    sub on_close ($stream) {
        my $state = $stream->data;
        $state->{close_calls}++;
        $state->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, request => '', eof_calls => 0, close_calls => 0 };

my $stream = T::HalfCloseStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

syswrite($b, 'request');
shutdown($b, SHUT_WR) or die "shutdown peer: $!";
$loop->run;

is($state->{request}, 'request', 'data is drained before EOF completion');
is($state->{eof_calls}, 1, 'on_eof fires once');
is($state->{close_calls}, 1, 'stream closes after both directions end');
ok($stream->is_write_ended, 'local writable side ended');
ok($stream->is_closed, 'stream closed after full duplex completion');

my $response = '';
my $n = sysread($b, $response, 1024);
is($n, 8, 'peer can read response written after its half-close');
is($response, 'response', 'response content is intact');

done_testing;
