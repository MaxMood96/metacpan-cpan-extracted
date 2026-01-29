use v5.40;
use Test2::V0;
use lib 'lib', '../lib';

# Mock Multicast socket before loading module
BEGIN {
    try {
        require IO::Socket::Multicast;
        diag 'Using IO::Socket::Multicast';
    }
    catch ($e) {
        diag $e;
        diag 'I guess we will simply mock it... hang on a sec.';
        no warnings 'once';
        *IO::Socket::Multicast::new = sub ( $class, %args ) {
            bless { domain => $args{domain} // 2 }, $class;
        };
        *IO::Socket::Multicast::mcast_add  = sub {1};
        *IO::Socket::Multicast::mcast_send = sub {1};
        *IO::Socket::Multicast::sockdomain = sub { shift->{domain} };
        $INC{'IO/Socket/Multicast.pm'}     = 1;
    }
}
#
use Net::Multicast::PeerDiscovery;
use Socket qw[AF_INET AF_INET6 pack_sockaddr_in inet_aton pack_sockaddr_in6 inet_pton];
#
subtest 'IPv4 Discovery' => sub {
    my $discovery = Net::Multicast::PeerDiscovery->new( domain => AF_INET );
    ok $discovery->is_available, 'Discovery available with mock';
    my $found;
    $discovery->on( 'peer_found', sub { $found = shift } );
    my $ih     = 'L' x 20;
    my $ih_hex = unpack( 'H*', $ih );
    my $msg    = "BT-SEARCH * HTTP/1.1\r\nPort: 6881\r\nInfohash: $ih_hex\r\n\r\n";
    my $sender = pack_sockaddr_in( 6771, inet_aton('192.168.1.50') );
    $discovery->_handle_packet( $msg, $sender );
    ok $found, 'Peer found via IPv4';
    is $found->{ip},   '192.168.1.50', 'Correct IP';
    is $found->{port}, 6881,           "Correct port";
};
subtest 'IPv6 Link-Local Discovery' => sub {
    skip_all 'IPv6 not supported' unless eval { pack_sockaddr_in6( 0, "\0" x 16 ); 1 };
    my $discovery = Net::Multicast::PeerDiscovery->new( domain => AF_INET6 );
    my $found;
    $discovery->on( peer_found => sub { $found = shift } );
    my $ih     = 'L' x 20;
    my $ih_hex = unpack( 'H*', $ih );
    my $msg    = "BT-SEARCH * HTTP/1.1\r\nPort: 6881\r\nInfohash: $ih_hex\r\n\r\n";
    my $sender = pack_sockaddr_in6( 6771, inet_pton( AF_INET6, 'fe80::1' ), 2, 0 );
    $discovery->_handle_packet( $msg, $sender );
    ok $found, 'Peer found via IPv6';
    is $found->{ip}, 'fe80::1%2', 'Preserved scope ID';
};
#
done_testing;
