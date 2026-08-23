use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX);

use Linux::Event::Loop;
use Linux::Event::Stream;

our ($LOOP, $ERROR);

{
    package T::TimedClientStream;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) {
        $main::ERROR = $error;
        $main::LOOP->stop;
    }
}

$LOOP = Linux::Event::Loop->new;
{
    no warnings 'redefine';
    local *Linux::Event::Stream::_Connection::_attempt_next = sub ($state) { };
    my $stream = T::TimedClientStream->connect(
        loop => $LOOP, sockaddr => '', family => AF_UNIX, timeout => 0.01,
    );
    is($stream->state, 'connecting', 'Stream starts in connecting state');
    $LOOP->run;

    is($stream->state, 'closed', 'deadline failure closes Stream');
    is($ERROR->type, 'timeout', 'deadline produces timeout type');
    is($ERROR->operation, 'connect', 'deadline identifies connection operation');
    is($ERROR->errno + 0, Errno::ETIMEDOUT() + 0,
        'deadline exposes ETIMEDOUT');
}

done_testing;
