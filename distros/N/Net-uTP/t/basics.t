use v5.40;
use Test2::V0;
use lib 'lib', '../lib';
use Net::uTP;
#
subtest Handshake => sub {
    isa_ok my $client = Net::uTP->new( conn_id_send => 100, conn_id_recv => 101 ), ['Net::uTP'];
    isa_ok my $server = Net::uTP->new( conn_id_send => 101, conn_id_recv => 100 ), ['Net::uTP'];

    # Client connects
    ok my $syn = $client->connect(), 'Client generated SYN';
    is $client->state, 'SYN_SENT', 'Client state SYN_SENT';

    # Server receives SYN and returns STATE (ACK)
    ok my $ack = $server->receive_packet($syn), '->receive_packet( ... )';
    ok $ack,                                    'Server generated ACK';
    is $server->state, 'CONNECTED', 'Server state CONNECTED';

    # Client receives ACK
    $client->receive_packet($ack);
    is $client->state, 'CONNECTED', 'Client state CONNECTED';
};
subtest 'Data Exchange' => sub {
    my $client = Net::uTP->new( conn_id_send => 100, conn_id_recv => 101 );
    my $server = Net::uTP->new( conn_id_send => 101, conn_id_recv => 100 );

    # Connect
    $server->receive_packet( $client->connect() );
    $client->receive_packet( $server->pack_header(2) );    # ST_STATE

    #
    my $received = '';
    ok $server->on( 'data', sub { $received .= shift } ), 'set "data" callback';
    #
    my $data = 'Hello Standalone μTP';
    is my $pkt = $client->send_data($data), D(), '->send_data( ... )';
    #
    is $server->receive_packet($pkt), D(),   '->receive_packet( ... )';
    is $received,                     $data, 'Server received correct data via events';
};
#
done_testing;
