package Linux::Event::Stream::_Deadline;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.102';

use parent 'Linux::Event::Timer';

sub on_timer ($timer) {
    my $state = $timer->data;
    my $stream = $state->{stream};
    $stream->_stream_deadline_fired($timer) if $stream;
    return;
}

1;
