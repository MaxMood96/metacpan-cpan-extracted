use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Fcntl;
use File::Temp qw(tempdir);

BEGIN { plan skip_all => 'needs Net::SSLeay' unless eval { require Net::SSLeay; 1 } }
Net::SSLeay::initialize();
plan skip_all => 'Net::SSLeay lacks CTX_get_mode' unless Net::SSLeay->can('CTX_get_mode');
require Proxy::Impersonate::Cert;
require Proxy::Impersonate::Connection;

my $tmp  = tempdir(CLEANUP => 1);
my $cert = Proxy::Impersonate::Cert->new(cert_dir => $tmp);

# _begin_tls must enable SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER (0x2) on the per-
# connection CTX. Without it, an upstream on_body that appends to wbuf between an
# SSL_write WANT_WRITE and its retry moves the Perl PV, and OpenSSL fails the retry
# with a fatal "bad write retry" -- the HTTPS response is then silently truncated
# (exactly the backpressure path HIWAT exists for). Assert the mode is set: that is
# deterministic, whereas provoking the moved-buffer retry itself is timing-dependent.
socketpair(my $srv_fd, my $peer_fd, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
fcntl($srv_fd, F_SETFL, (fcntl($srv_fd, F_GETFL, 0) | O_NONBLOCK)) or die "fcntl: $!";

my $conn = Proxy::Impersonate::Connection->new(
    fd => $srv_fd, cert => $cert, multi => undef, make_handle => sub {},
);
$conn->{connect_host} = 'example.com:443';
# SSL_accept on a peerless non-blocking socket returns WANT_READ and does not block;
# the CTX (with the mode) is built before that, so the assertion is independent of it.
$conn->_begin_tls;

ok($conn->{ctx}, '_begin_tls created a per-connection SSL CTX');
ok(Net::SSLeay::CTX_get_mode($conn->{ctx}) & 0x2,
   '_begin_tls sets SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER (guards HTTPS truncation on the backpressure write path)');

$conn->_close;
close $peer_fd;
done_testing;
