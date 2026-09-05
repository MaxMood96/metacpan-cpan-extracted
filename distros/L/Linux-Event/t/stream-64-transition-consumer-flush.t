use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::_ByteStream;

{
    package T::TransitionConsumerBase;
    use parent 'Linux::Event::_ByteStream';
    BEGIN {
        Linux::Event::_ByteStream->_declare_consumer(
            __PACKAGE__,
            Linux::Event::_ByteStream::TestSupport->_test_consumer_definition(
                'transition-trace'
            ),
        );
    }
}

{
    package T::TransitionConsumerLine;
    use parent -norequire, 'T::TransitionConsumerBase';
    use Linux::Event::Framer 'Delimiter', "\n";
}

{
    package T::TransitionConsumerFixed;
    use parent -norequire, 'T::TransitionConsumerBase';
    use Linux::Event::Framer 'Fixed', size => 3;
}

socketpair(my $stream_fh, my $peer_fh,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $stream = T::TransitionConsumerLine->new(
    loop => $loop, fh => $stream_fh,
);
my $xs_state = $stream->{xs_state};

$xs_state->_test_consumer_arm(sub {
    $stream->transition_to('T::TransitionConsumerFixed');
});
syswrite($peer_fh, "SWITCH\nabc") == 10 or die "syswrite: $!";
$loop->run_for(0.02);

is_deeply(
    $xs_state->_test_consumer_trace,
    ['message:SWITCH', 'flush', 'message:abc', 'flush'],
    'old protocol consumer flush precedes first new protocol message',
);
isa_ok($stream, 'T::TransitionConsumerFixed');

$stream->close;
close $peer_fh;
done_testing;
