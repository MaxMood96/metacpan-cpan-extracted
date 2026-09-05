use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

{
    package T::LimitedLineStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'Delimiter', "\n", max_frame => 4;
    sub on_message ($stream, $message) {
        Test::More::fail('oversized native frame must not emit a message');
    }
    sub on_error ($stream, $error) { $stream->data->{error} = $error }
    sub on_close ($stream) {
        my $state = $stream->data;
        $state->{closed}++;
        $state->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, error => undef, closed => 0 };

my $stream = T::LimitedLineStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

eval { $stream->send('12345') };
like($@, qr/exceeds max_frame=4/, 'outbound delimiter framing enforces max_frame');

syswrite($b, "12345\n");
$loop->run;

isa_ok($state->{error}, 'Linux::Event::Error');
is($state->{error}->type, 'framing', 'native parser failure becomes framing error');
like($state->{error}->message, qr/max_frame=4/, 'framing error preserves parser context');
is($state->{closed}, 1, 'framing failure closes stream exactly once');
ok($stream->is_closed, 'stream is closed');

done_testing;
