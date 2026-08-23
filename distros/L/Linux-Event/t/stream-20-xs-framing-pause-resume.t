use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::PausableFramedStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', '|';
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        push @{ $state->{got} }, $message;
        if (@{ $state->{got} } == 1) {
            $stream->pause_read;
        }
        $state->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, got => [] };
my $stream = T::PausableFramedStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

syswrite($b, 'one|two|');
$loop->run;
is_deeply($state->{got}, ['one'], 'pause inside native on_message stops buffered frame dispatch');
$stream->resume_read;
is_deeply($state->{got}, ['one', 'two'], 'resume immediately dispatches already-buffered complete frame');

$stream->close;
close $b;
done_testing;
