use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::_ByteStream;

{
    package T::HostLifetimeBase;
    use parent 'Linux::Event::_ByteStream';
    BEGIN {
        Linux::Event::_ByteStream->_declare_consumer(
            __PACKAGE__, Linux::Event::_ByteStream::TestSupport->_test_consumer_definition,
        );
    }
}

{
    package T::HostLifetimeLine;
    use parent -norequire, 'T::HostLifetimeBase';
    use Linux::Event::Framer 'Delimiter', "\n";
}

{
    package T::HostLifetimeFixed;
    use parent -norequire, 'T::HostLifetimeBase';
    use Linux::Event::Framer 'Fixed', size => 3;
}

socketpair(my $stream_fh, my $peer_fh,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $stream = T::HostLifetimeLine->new(loop => $loop, fh => $stream_fh);
my $destroyed_before = Linux::Event::_ByteStream::TestSupport->_test_consumer_destroy_count;

$stream->transition_to('T::HostLifetimeFixed', input => 'abc');
my $continued = Linux::Event::_ByteStream::TestSupport::_test_consumer_external_arm(
    $stream,
    sub { $stream->close },
);

ok($continued,
    'provider frame safely continues after synchronous resume closes Stream');
ok($stream->is_closed, 'reentrant callback closes Stream');
ok(!defined($stream->{xs_state}), 'Stream releases its XSState ownership');
ok(!defined(fileno($stream_fh)), 'reentrant close releases the descriptor');
is($loop->resources->{registered_fds}, 0,
    'reentrant close releases the watcher registration');
cmp_ok(Linux::Event::_ByteStream::TestSupport->_test_consumer_destroy_count, '>',
    $destroyed_before,
    'provider context destruction is deferred until host release');

close $peer_fh;
done_testing;
