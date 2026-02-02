use v5.40;
use Test2::V1;
use lib '../lib';
use feature 'class';

# Mock Socket and HTTP::Tiny
my $socket_recv_data;
my $http_content;

BEGIN {
    *CORE::GLOBAL::select = sub { return 1 }
}
no warnings qw[experimental::class redefine once];
#
*IO::Socket::INET::new = sub { return bless {}, 'MockSocket' };

package MockSocket {
    sub send       {1}
    sub fileno     {1}
    sub sockdomain {2}
    sub sockhost   {'127.0.0.1'}
    sub mcast_add  {1}

    sub recv {
        return unless $main::socket_recv_data;
        $_[1] = $main::socket_recv_data;
        $main::socket_recv_data = undef;
        return "fake_addr";
    }
};
*HTTP::Tiny::new = sub { return bless {}, 'MockHTTP' };

package MockHTTP {

    sub get {
        my ( $self, $url ) = @_;
        if ( $url eq 'http://192.168.1.1:5000/desc.xml' ) {
            return { success => 1, content => $main::http_content };
        }
        return { success => 0 };
    }

    sub post {
        my ( $self, $url, $args ) = @_;
        if ( $args->{content} =~ /GetExternalIPAddress/ ) {
            return { success => 1, content => '<NewExternalIPAddress>4.3.2.1</NewExternalIPAddress>' };
        }
        return { success => 1, content => '' };
    }
};
use Acme::UPnP;
T2->subtest(
    'Object Creation' => sub {
        my $upnp = Acme::UPnP->new();
        T2->ok( $upnp,               'Acme::UPnP object created' );
        T2->ok( $upnp->is_available, 'is_available returns true' );
    }
);
T2->subtest(
    'Discovery' => sub {
        $main::socket_recv_data = "HTTP/1.1 200 OK\r\nLocation: http://192.168.1.1:5000/desc.xml\r\n\r\n";
        $main::http_content     = <<'XML';
<root>
    <service>
        <serviceType>urn:schemas-upnp-org:service:WANIPConnection:1</serviceType>
        <controlURL>/ctl/IPConn</controlURL>
    </service>
</root>
XML
        my $upnp = Acme::UPnP->new();
        T2->ok( $upnp->discover_device(), 'discover_device returns true' );
    }
);
T2->subtest(
    'Port Mapping' => sub {
        $main::socket_recv_data = "HTTP/1.1 200 OK\r\nLocation: http://192.168.1.1:5000/desc.xml\r\n\r\n";
        my $upnp = Acme::UPnP->new();
        $upnp->discover_device();
        T2->ok( $upnp->map_port( 6881, 6881, 'TCP', 'Test' ), 'map_port returns true' );
        T2->ok( $upnp->unmap_port( 6881, 'TCP' ),             'unmap_port returns true' );
    }
);
T2->subtest(
    'External IP' => sub {
        $main::socket_recv_data = "HTTP/1.1 200 OK\r\nLocation: http://192.168.1.1:5000/desc.xml\r\n\r\n";
        my $upnp = Acme::UPnP->new();
        $upnp->discover_device();
        T2->is( $upnp->get_external_ip(), '4.3.2.1', 'get_external_ip returns mocked IP' );
    }
);
#
T2->done_testing;
