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

use Linux::Event::Signal;
use Linux::Event::Stream;
use Linux::Event::Timer;

{
    package T::ThreadDescriptor::Stream;
    use parent 'Linux::Event::Stream';
    sub on_data ($self, $bytes) { return }
}

{
    package T::ThreadDescriptor::Timer;
    use parent 'Linux::Event::Timer';
    sub on_timer ($self) { return }
}

{
    package T::ThreadDescriptor::Signal;
    use parent 'Linux::Event::Signal';
    sub on_signal ($self, $number, $count) { return }
}

socketpair(my $parent_stream_fh, my $parent_peer_fh,
    AF_UNIX, SOCK_STREAM, 0) or die "socketpair: $!";
T::ThreadDescriptor::Stream->new(fh => $parent_stream_fh)->close;
close $parent_peer_fh;
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
    [1, 1, 1],
    'child ithread lazily rebuilds Stream, Timer, and Signal descriptors',
);

done_testing;
