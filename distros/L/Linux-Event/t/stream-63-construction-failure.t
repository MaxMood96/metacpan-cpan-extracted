use v5.36;
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(weaken);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::_ByteStream;
use Linux::Event::_ByteStream;

{
    package T::FailingRegistrationLoop;
    use parent 'Linux::Event::Loop';
    sub watch_fd ($loop, @args) {
        die "synthetic watcher registration failure\n";
    }
}

{
    package T::RegistrationFailure;
    use parent 'Linux::Event::_ByteStream';
    our $constructed;

    sub on_data ($stream, $bytes) { return }

    sub _prepare_handles ($self) {
        $self->SUPER::_prepare_handles;
        $constructed = $self;
        Scalar::Util::weaken($constructed);
        return;
    }
}

{
    package T::ConsumerCreateFailure;
    use parent 'Linux::Event::_ByteStream';
    use Linux::Event::Framer 'Delimiter', "\n";
    our $constructing;

    Linux::Event::_ByteStream->_declare_consumer(
        __PACKAGE__,
        Linux::Event::_ByteStream::TestSupport->_test_consumer_definition('create-failure'),
    );

    sub _prepare_handles ($self) {
        $constructing = $self;
        Scalar::Util::weaken($constructing);
        $self->SUPER::_prepare_handles;
        return;
    }
}

{
    package T::SocketRegistrationFailure;
    use parent 'Linux::Event::_ByteStream';
    our $constructing;

    sub on_data ($stream, $bytes) { return }

    sub _configure_socket ($self, @args) {
        $constructing = $self;
        Scalar::Util::weaken($constructing);
        return $self->SUPER::_configure_socket(@args);
    }
}

pipe(my $read_fh, my $write_fh) or die "pipe: $!";
my $loop = T::FailingRegistrationLoop->new;
my $ok = eval {
    T::RegistrationFailure->new(loop => $loop, read_fh => $read_fh);
    1;
};

ok(!$ok, 'constructor reports watcher registration failure');
like($@, qr/synthetic watcher registration failure/,
    'registration failure preserves its diagnostic');
ok(!defined($T::RegistrationFailure::constructed),
    'failed constructor breaks the Stream and XSState ownership cycle');
ok(!defined(fileno($read_fh)), 'failed constructor closes its owned handle');
is($loop->resources->{registered_fds}, 0,
    'failed constructor strands no epoll registration');

close $write_fh;

pipe(my $consumer_read_fh, my $consumer_write_fh) or die "pipe: $!";
$ok = eval {
    T::ConsumerCreateFailure->new(read_fh => $consumer_read_fh);
    1;
};
ok(!$ok, 'constructor reports native consumer context creation failure');
like($@, qr/failed to create context/,
    'consumer creation failure preserves its diagnostic');
ok(!defined($T::ConsumerCreateFailure::constructing),
    'consumer creation failure leaves no partial Stream/XSState cycle');
ok(!defined(fileno($consumer_read_fh)),
    'consumer creation failure closes the owned readable handle');

close $consumer_write_fh;

socketpair(my $socket_fh, my $socket_peer,
    AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
$ok = eval {
    T::SocketRegistrationFailure->new(
        loop => T::FailingRegistrationLoop->new,
        fh   => $socket_fh,
    );
    1;
};
ok(!$ok, 'Socket constructor reports watcher registration failure');
like($@, qr/synthetic watcher registration failure/,
    'Socket registration failure preserves its diagnostic');
ok(!defined($T::SocketRegistrationFailure::constructing),
    'failed Socket attachment breaks the Stream and XSState ownership cycle');
ok(!defined(fileno($socket_fh)),
    'failed Socket attachment closes its owned handle');

close $socket_peer;
done_testing;
