use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::DelimiterErrorStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', '<E>', max_frame => 4;
    sub on_message ($stream, $message) {
        Test::More::fail('oversized frame must not emit');
    }
    sub on_error ($stream, $error) { $stream->data->{error} = $error }
    sub on_close ($stream) { $stream->data->{loop}->stop }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, error => undef };
my $stream = T::DelimiterErrorStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

syswrite($b, '12345<E>');
$loop->run;
isa_ok($state->{error}, 'Linux::Event::Error');
is($state->{error}->type, 'framing', 'native delimiter limit reports framing error');
like($state->{error}->message, qr/max_frame=4/, 'native error preserves max_frame context');
ok($stream->is_closed, 'framing error closes Stream');
close $b;
done_testing;
