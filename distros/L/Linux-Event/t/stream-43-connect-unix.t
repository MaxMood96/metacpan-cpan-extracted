use v5.36;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Socket qw(AF_UNIX SOCK_STREAM SOMAXCONN pack_sockaddr_un);

use Linux::Event::Loop;
use Linux::Event::Stream;

our ($LOOP, $READY, $ERROR);

{
    package T::UnixClientStream;
    use parent 'Linux::Event::Stream';
    sub on_ready ($stream) {
        $main::READY++;
        $main::LOOP->stop;
    }
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) {
        $main::ERROR = $error;
        $main::LOOP->stop;
    }
}

my $directory = tempdir(CLEANUP => 1);
my $path = "$directory/connect.sock";
socket(my $listener, AF_UNIX, SOCK_STREAM, 0)
    or plan skip_all => "Unix stream sockets unavailable: $!";
bind($listener, pack_sockaddr_un($path)) or die "bind: $!";
listen($listener, SOMAXCONN) or die "listen: $!";

$LOOP = Linux::Event::Loop->new;
my $data = { target => 'unix' };
my $stream = T::UnixClientStream->connect(
    loop => $LOOP, unix => $path, timeout => 1, data => $data,
);

is($READY // 0, 0, 'immediate Unix success is deferred to the Loop');
is($stream->state, 'connecting', 'Stream remains connecting until dispatch');
is($stream->data, $data, 'Stream preserves application data');

accept(my $server_peer, $listener) or die "accept: $!";
$LOOP->run;

is($READY, 1, 'on_ready runs once');
ok(!$ERROR, 'success does not report an error');
is($stream->state, 'active', 'successful Stream becomes active');
ok(defined fileno($stream->fh), 'Stream owns the connected filehandle');

$stream->write('ok');
is(sysread($server_peer, my $bytes, 2), 2, 'connected Stream remains usable');
is($bytes, 'ok', 'connected Stream carries bytes');

$stream->close;
close $server_peer;
close $listener;
done_testing;
