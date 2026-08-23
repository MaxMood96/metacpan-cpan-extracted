use v5.36;
use strict;
use warnings;

use Socket qw(
    AF_INET AF_UNIX INADDR_ANY SOCK_STREAM
    pack_sockaddr_in pack_sockaddr_un unpack_sockaddr_in
);
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Stream;

our @ERRORS;

{
    package T::LocalBindClient;
    use parent 'Linux::Event::Stream';
    sub on_data ($self, $bytes) { }
    sub on_error ($self, $error) {
        push @main::ERRORS, $error;
        $self->loop->stop;
    }
}

my $loop = Linux::Event::Loop->new;
my $stream = $loop->add(T::LocalBindClient->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_host => '::1',       # optional
));
$loop->run;

is(scalar @ERRORS, 1, 'incompatible local address reports one error');
is($ERRORS[0]->type, 'socket_configuration',
    'local address mismatch is a socket configuration error');
is($ERRORS[0]->operation, 'bind', 'error identifies local binding');
is($ERRORS[0]->option, 'local_host', 'error identifies local_host');
like($ERRORS[0]->message, qr/address family/, 'error explains mismatch');
ok($stream->is_terminal, 'incompatible connection becomes terminal');

my $ephemeral = T::LocalBindClient->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_port => 0,           # optional explicit ephemeral bind
);
ok($ephemeral->{connection}{local_bind},
    'explicit local_port zero retains the local-bind request');
$ephemeral->close;

socket(my $occupied, AF_INET, SOCK_STREAM, 0) or die "socket: $!";
bind($occupied, pack_sockaddr_in(0, INADDR_ANY)) or die "bind: $!";
my ($occupied_port) = unpack_sockaddr_in(getsockname($occupied));
@ERRORS = ();
my $collision_loop = Linux::Event::Loop->new;
my $collision = $collision_loop->add(T::LocalBindClient->connect(
    host       => '127.0.0.1', # required
    port       => 9,           # required
    local_port => $occupied_port, # optional source port
));
$collision_loop->run;
is($ERRORS[0]->type, 'socket_configuration',
    'local bind syscall failure is a socket configuration error');
is($ERRORS[0]->option, 'local_port',
    'local bind syscall failure identifies local_port');
ok($collision->is_terminal, 'local port collision closes the Stream');
close $occupied;

my $packed = pack_sockaddr_un('/tmp/linux-event-unused.sock');
my $error = eval {
    T::LocalBindClient->connect(
        sockaddr   => $packed,  # required for packed-address mode
        family     => AF_UNIX,  # required for packed-address mode
        local_port => 0,        # invalid for Unix
    );
    '';
} // $@;
like("$error", qr/require an IPv4 or IPv6 sockaddr/,
    'packed Unix targets reject Internet local-binding options');

done_testing;
