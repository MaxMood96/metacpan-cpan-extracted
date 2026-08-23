use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::EndDelimitedStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', '<END>';
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        push @{ $state->{messages} }, $message;
        $state->{loop}->stop if @{ $state->{messages} } == 2;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, messages => [] };

my $stream = T::EndDelimitedStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

syswrite($b, 'hello<EN');
$loop->run_once(0);
is_deeply($state->{messages}, [], 'delimiter split across reads is retained');

syswrite($b, 'D>world<END>tail');
$loop->run;
is_deeply($state->{messages}, ['hello', 'world'], 'multiple frames are emitted and delimiter stripped');

ok($stream->send('reply'), 'send uses outbound framing');
my $wire = '';
is(sysread($b, $wire, 1024), 10, 'peer receives framed payload');
is($wire, 'reply<END>', 'delimiter framer appends delimiter on send');

$stream->close;
done_testing;
