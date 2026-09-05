use v5.36;
use strict;
use warnings;

use Config;
use Test::More;

plan skip_all => 'Perl was built without ithreads'
    if !$Config{useithreads};

require threads;

use POSIX qw(SIGUSR1);
use Socket qw(AF_UNIX SOCK_STREAM);

use Linux::Event::Kernel::Signal;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::Kernel::Timer;

{
    package T::ThreadDescriptor::Stream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($self, $bytes) { return }
}

{
    package T::ThreadDescriptor::ConsumerBase;
    use parent 'Linux::Event::IO::Sock::Stream';
    BEGIN {
        Linux::Event::IO::Sock::Stream->_declare_consumer(
            __PACKAGE__, Linux::Event::_ByteStream::TestSupport->_test_consumer_definition,
        );
    }
}

{
    package T::ThreadDescriptor::ConsumerLine;
    use parent -norequire, 'T::ThreadDescriptor::ConsumerBase';
    use Linux::Event::Framer 'Delimiter', "\n";
}

{
    package T::ThreadDescriptor::Timer;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($self) { return }
}

{
    package T::ThreadDescriptor::Signal;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($self, $number, $count) { return }
}

socketpair(my $parent_stream_fh, my $parent_peer_fh,
    AF_UNIX, SOCK_STREAM, 0) or die "socketpair: $!";
T::ThreadDescriptor::Stream->new(fh => $parent_stream_fh)->close;
close $parent_peer_fh;
socketpair(my $parent_consumer_fh, my $parent_consumer_peer,
    AF_UNIX, SOCK_STREAM, 0) or die "consumer socketpair: $!";
T::ThreadDescriptor::ConsumerLine->new(fh => $parent_consumer_fh)->close;
close $parent_consumer_peer;
T::ThreadDescriptor::Timer->new(after => 60)->cancel;
T::ThreadDescriptor::Signal->new(signals => SIGUSR1)->cancel;

my $worker = threads->create(sub {
    my @result;

    socketpair(my $stream_fh, my $peer_fh, AF_UNIX, SOCK_STREAM, 0)
        or die "socketpair in child ithread: $!";
    my $stream = T::ThreadDescriptor::Stream->new(fh => $stream_fh);
    push @result, $stream->isa('T::ThreadDescriptor::Stream');
    $stream->close;
    close $peer_fh;

    socketpair(my $consumer_fh, my $consumer_peer,
        AF_UNIX, SOCK_STREAM, 0) or die "consumer socketpair in child: $!";
    my $consumer = T::ThreadDescriptor::ConsumerLine->new(fh => $consumer_fh);
    push @result, $consumer->isa('T::ThreadDescriptor::ConsumerLine')
        && $consumer->{xs_state}->consumer_paused;
    $consumer->close;
    close $consumer_peer;

    my $timer = T::ThreadDescriptor::Timer->new(after => 60);
    push @result, $timer->isa('T::ThreadDescriptor::Timer');
    $timer->cancel;

    my $signal = T::ThreadDescriptor::Signal->new(signals => SIGUSR1);
    push @result, $signal->isa('T::ThreadDescriptor::Signal');
    $signal->cancel;

    return \@result;
});

my $result = $worker->join;
is_deeply(
    $result,
    [1, 1, 1, 1],
    'child ithread lazily rebuilds Stream, consumer, Timer, and Signal descriptors',
);

done_testing;
