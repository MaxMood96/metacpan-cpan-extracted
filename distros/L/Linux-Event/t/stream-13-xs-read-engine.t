use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::SmallReadStream;
    use parent 'Linux::Event::Stream';
    sub stream_options ($class) { return read_size => 4 }
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{got} .= $bytes;
        $state->{loop}->stop if length($state->{got}) >= 10;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";

my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, got => '' };

my $stream = T::SmallReadStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

isa_ok($stream->{xs_state}, 'Linux::Event::Stream::XSState');
isa_ok($stream->{descriptor}{xs}, 'Linux::Event::Stream::XSDescriptor');

is(syswrite($b, 'abcdefghij'), 10, 'peer wrote test bytes');
$loop->run;
is($state->{got}, 'abcdefghij', 'native read engine drains and delivers bytes');

my $stats = $stream->{xs_state}->stats;
ok($stats->{read_ready_calls} >= 1, 'native readiness handler ran');
ok($stats->{read_calls} >= 3, 'native engine performed multiple small read calls');
is($stats->{bytes_read}, 10, 'native byte count is exact');
ok($stats->{delivery_calls} >= 3, 'delivery callback follows successful reads');

$stream->close;
close $b;

done_testing;
