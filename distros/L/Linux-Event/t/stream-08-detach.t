use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

{
    package T::DetachStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) { $stream->data->{data_calls}++ }
    sub on_close ($stream) { $stream->data->{close_calls}++ }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { data_calls => 0, close_calls => 0 };

my $stream = T::DetachStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

my $fh = $stream->detach;
ok(defined fileno($fh), 'detach returns an open filehandle');
ok($stream->is_closed, 'Stream abstraction is no longer active');
is($state->{close_calls}, 0, 'detach does not claim underlying resource was closed');

syswrite($b, 'still open');
my $buf = '';
is(sysread($fh, $buf, 1024), 10, 'detached handle remains usable');
is($buf, 'still open', 'detached handle receives bytes');
$loop->run_once(0);
is($state->{data_calls}, 0, 'detached Stream watcher was cancelled');

close $fh;
close $b;
done_testing;
