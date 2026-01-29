use v5.40;
use feature 'class';
no warnings 'experimental::class';
#
class Net::Multicast::PeerDiscovery v1.0.0 {
    use Socket qw[
        pack_sockaddr_in unpack_sockaddr_in inet_aton inet_ntoa
        pack_sockaddr_in6 unpack_sockaddr_in6 inet_pton inet_ntop
        AF_INET AF_INET6 sockaddr_family
    ];
    use IO::Select;
    use Carp qw[carp croak];
    #
    BEGIN {
        # Polyfill for systems where Socket::pack_sockaddr_in6 is "not implemented" (e.g. some Windows runners)
        # or missing entirely.
        if ( !defined &pack_sockaddr_in6 || !eval { pack_sockaddr_in6( 0, "\0" x 16 ); 1 } ) {
            no warnings 'redefine';
            *pack_sockaddr_in6 = sub ( $port, $ip, $scope_id = 0, $flowinfo = 0 ) {
                my $family = eval { AF_INET6() } // 23;    # Default to 23 (Win32) if missing, though risky.
                return pack( 'S n N a16 I', $family, $port, $flowinfo, $ip, $scope_id );
            };
            *unpack_sockaddr_in6 = sub ($packed) {
                my ( $family, $port, $flowinfo, $ip, $scope_id ) = unpack( 'S n N a16 I', $packed );
                return ( $port, $ip, $scope_id, $flowinfo );
            };
        }
    }
    #
    field $port   : param //= 6771;
    field $domain : param //= undef;
    field $socket;
    field %on;
    field $available : reader(is_available) = 0;
    #
    # BEP 14 Multicast group and port
    my $MCAST_ADDR4 = '239.192.152.143';
    my $MCAST_ADDR6 = 'ff15::efc0:988f';
    my $MCAST_PORT  = 6771;
    #
    ADJUST {
        try {
            require IO::Socket::Multicast;

            # Use provided domain or try to auto-select
            if ( defined $domain ) {
                $socket = IO::Socket::Multicast->new( LocalPort => $MCAST_PORT, Proto => 'udp', ReuseAddr => 1, Domain => $domain ) or die $!;
            }
            else {
                $socket = IO::Socket::Multicast->new( LocalPort => $MCAST_PORT, Proto => 'udp', ReuseAddr => 1, Domain => AF_INET6 )
                    // IO::Socket::Multicast->new( LocalPort => $MCAST_PORT, Proto => 'udp', ReuseAddr => 1, Domain => AF_INET );
            }
            die "Could not create discovery socket: $!" unless $socket;
            $socket->mcast_add($MCAST_ADDR4) if $socket->sockdomain == AF_INET // $socket->sockdomain == AF_INET6;
            $socket->mcast_add($MCAST_ADDR6) if $socket->sockdomain == AF_INET6;
            $available = 1;
        }
        catch ($e) {
            carp "IO::Socket::Multicast not available. Disabled: $e";
            require IO::Socket::IP;
            $socket = IO::Socket::IP->new( Proto => 'udp', LocalPort => 0 );
        }
    }
    method on ( $event, $cb ) { push $on{$event}->@*, $cb }

    method _emit ( $event, @args ) {
        for my $cb ( $on{$event}->@* ) {
            try { $cb->(@args) } catch ($e) {
                carp "Discovery callback for $event failed: $e"
            }
        }
    }

    method announce ( $info_hash, $bt_port ) {
        return unless $available;
        my $ih_hex = unpack( 'H*', $info_hash );
        my $msg    = "BT-SEARCH * HTTP/1.1\r\n" . "Host: %s:%d\r\n" . "Port: $bt_port\r\n" . "Infohash: $ih_hex\r\n" . "\r\n\r\n";

        # Announce to IPv4
        $socket->mcast_send( sprintf( $msg, $MCAST_ADDR4, $MCAST_PORT ), "$MCAST_ADDR4:$MCAST_PORT" );

        # Announce to IPv6
        $socket->mcast_send( sprintf( $msg, "[$MCAST_ADDR6]", $MCAST_PORT ), "[$MCAST_ADDR6]:$MCAST_PORT" ) if $socket->sockdomain == AF_INET6;
    }

    method tick ( $timeout //= 0 ) {
        return unless $available;
        my $sel = IO::Select->new($socket);
        while ( $sel->can_read($timeout) ) {
            my $sender = $socket->recv( my $data, 1024 );
            $self->_handle_packet( $data, $sender ) if defined $data;
            last                                    if $timeout == 0;
        }
    }

    method _handle_packet ( $data, $sender ) {
        if ( $data =~ /^BT-SEARCH/i ) {
            my ($port)   = $data =~ /^Port:\s*(\d+)/mi;
            my ($ih_hex) = $data =~ /^Infohash:\s*([a-fA-F0-9]+)/mi;
            if ( $port && $ih_hex ) {
                my $family = sockaddr_family($sender);
                my ( $ip, $scope_id );
                if ( $family == AF_INET ) {
                    ( undef, my $ip_bin ) = unpack_sockaddr_in($sender);
                    $ip = inet_ntoa($ip_bin);
                }
                elsif ( $family == AF_INET6 ) {
                    ( undef, my $ip_bin, $scope_id ) = unpack_sockaddr_in6($sender);
                    $ip = inet_ntop( AF_INET6, $ip_bin );

                    # RFC 6724 / IPv6 Link-Local scope handling
                    $ip .= '%' . $scope_id if $ip =~ /^fe80:/i && $scope_id;
                }
                $self->_emit( 'peer_found', { ip => $ip, port => $port, info_hash => pack( 'H*', $ih_hex ) } ) if $ip;
            }
        }
    }
};
1;
