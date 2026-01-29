use v5.42;
use feature 'class';
no warnings 'experimental::class';
#
class Net::uTP::Manager v1.0.0 {
    use Net::uTP;
    use Socket qw[sockaddr_family AF_INET AF_INET6 unpack_sockaddr_in unpack_sockaddr_in6 inet_ntop];
    use Carp   qw[carp croak];
    #
    field %connections;
    field %on;
    #
    method on ( $event, $cb ) { push $on{$event}->@*, $cb }

    method _emit ( $event, @args ) {
        for my $cb ( $on{$event}->@* ) {
            try { $cb->(@args) } catch ($e) {
                carp "uTP Manager event $event failed: $e"
            };
        }
    }

    method handle_packet ( $data, $sender_addr ) {
        my ( $port, $ip ) = $self->_unpack_addr($sender_addr);
        return unless $ip;
        return if length($data) < 20;
        my ( $vt, $ext, $conn_id ) = unpack( 'C C n', $data );
        my $type = $vt & 0x0F;
        my $key  = "$ip:$port:$conn_id";
        my $utp  = $connections{$key};
        if ( !$utp && $type == 4 ) {    # ST_SYN
            $utp = Net::uTP->new( conn_id_send => $conn_id + 1, conn_id_recv => $conn_id, );
            $connections{ "$ip:$port:" . ($conn_id) } = $utp;
            $self->_emit( 'new_connection', $utp, $ip, $port );
        }
        if ($utp) {
            my $res = $utp->receive_packet($data);
            delete $connections{$key} if $utp->state eq 'CLOSED';
            return $res;
        }
        return undef;
    }

    method new_connection ( $ip, $port ) {
        my $send_id = int rand 65535;
        my $recv_id = $send_id + 1;
        my $utp     = Net::uTP->new( conn_id_send => $send_id, conn_id_recv => $recv_id );
        $connections{"$ip:$port:$recv_id"} = $utp;
        $utp;
    }

    method tick ($delta) {
        my @to_send;
        for my $key ( keys %connections ) {
            my $utp = $connections{$key};
            my $res = $utp->tick($delta);
            if ($res) {
                my ( $ip, $port, $cid ) = split( /:/, $key );
                push @to_send, { ip => $ip, port => $port, data => $res };
            }
            delete $connections{$key} if $utp->state eq 'CLOSED';
        }
        \@to_send;
    }

    method _unpack_addr ($addr) {
        my $family = eval { sockaddr_family($addr) };
        return unless defined $family;
        if ( $family == AF_INET ) {
            my ( $port, $ip_bin ) = unpack_sockaddr_in($addr);
            return ( $port, inet_ntop( AF_INET, $ip_bin ) );
        }
        elsif ( $family == AF_INET6 ) {
            my ( $port, $ip_bin ) = unpack_sockaddr_in6($addr);
            return ( $port, inet_ntop( AF_INET6, $ip_bin ) );
        }
        return;
    }
};
1;
