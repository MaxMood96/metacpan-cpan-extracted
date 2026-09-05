use v5.36;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Socket qw(AF_UNIX SOCK_STREAM SOMAXCONN pack_sockaddr_un);

use Linux::Event::Error;
use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

our ($LOOP, $ERROR, $READY, $CALLS);

{
    package T::FailedClientStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_ready ($stream) { $main::READY++ }
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) {
        $main::ERROR = $error;
        $main::LOOP->stop;
    }
}

$LOOP = Linux::Event::Loop->new;
my $failed = T::FailedClientStream->connect(
    loop => $LOOP, sockaddr => '', family => 9999, timeout => 1,
);
ok(!$ERROR, 'immediate socket failure is deferred to the Loop');
is($failed->state, 'connecting', 'operational failure is initially pending');
$LOOP->run;

isa_ok($ERROR, 'Linux::Event::Error');
is($ERROR->type, 'socket', 'socket creation failure is typed');
is($failed->state, 'closed', 'failed Stream closes');
is($failed->last_error, $ERROR, 'Stream retains terminal Error');
is($READY // 0, 0, 'failure does not call on_ready');

our $THROW_CLOSE = 0;
{
    package T::ThrowingErrorStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) { die "stream error callback failed\n" }
    sub on_close ($stream) { $main::THROW_CLOSE++ }
}

my $throw_loop = Linux::Event::Loop->new;
my $throwing = T::ThrowingErrorStream->connect(
    loop => $throw_loop, sockaddr => '', family => 9999, timeout => 1,
);
my $throw_error = eval { $throw_loop->run; '' } // $@;
like("$throw_error", qr/stream error callback failed/,
    'on_error exception propagates from Loop dispatch');
is($throwing->state, 'closed',
    'on_error exception cannot strand a failed Stream');
is($THROW_CLOSE, 1,
    'failed Stream still performs its one close notification');

{
    package T::ClosedClientStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_ready ($stream) { $main::CALLS++ }
    sub on_data ($stream, $bytes) { }
    sub on_error ($stream, $error) { $main::CALLS++ }
}

my $directory = tempdir(CLEANUP => 1);
my $path = "$directory/cancel.sock";
SKIP: {
    socket(my $listener, AF_UNIX, SOCK_STREAM, 0)
        or skip "Unix stream sockets unavailable: $!", 3;
    bind($listener, pack_sockaddr_un($path)) or die "bind: $!";
    listen($listener, SOMAXCONN) or die "listen: $!";

    my $closed = T::ClosedClientStream->connect(
        loop => $LOOP, unix => $path,
    );
    accept(my $server_peer, $listener) or die "accept: $!";
    is($closed->close, $closed, 'close returns the Stream');
    is($closed->state, 'closed', 'close ends a connecting Stream');
    $LOOP->run_once(20);
    is($CALLS // 0, 0, 'close suppresses readiness and error callbacks');

    close $server_peer;
    close $listener;
}

done_testing;
