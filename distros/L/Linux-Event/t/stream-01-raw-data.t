use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::RawDataStream;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{got} .= $bytes;
        $state->{loop}->stop if $state->{got} eq 'hello stream';
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, got => '' };

my $stream = T::RawDataStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

is($stream->write(''), 1, 'empty write is successful');
is(syswrite($b, 'hello stream'), 12, 'peer wrote bytes');
$loop->run;

is($state->{got}, 'hello stream', 'on_data receives incoming bytes');
is($stream->pending_bytes, 0, 'nothing queued for output');
ok(!$stream->is_closed, 'stream remains open');

$stream->close;
ok($stream->is_closed, 'close is immediate');

done_testing;
