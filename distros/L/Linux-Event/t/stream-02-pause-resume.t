use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

{
    package T::PauseStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{calls}++;
        $state->{got} .= $bytes;
        $state->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, calls => 0, got => '' };

my $stream = T::PauseStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

$stream->pause_read;
ok($stream->is_read_paused, 'read side is paused');
syswrite($b, 'paused');
$loop->run_once(0);
is($state->{calls}, 0, 'paused stream does not deliver data');

$stream->resume_read;
ok(!$stream->is_read_paused, 'read side resumed');
$loop->run;
is($state->{got}, 'paused', 'queued kernel data delivered after resume');

$stream->close;
done_testing;
