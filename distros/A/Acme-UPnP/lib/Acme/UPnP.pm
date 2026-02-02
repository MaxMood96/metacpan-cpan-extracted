use v5.40;
use feature 'class';
no warnings 'experimental::class';
#
class Acme::UPnP v1.0.0 {
    use Carp qw[carp croak];
    use IO::Socket::INET;
    use HTTP::Tiny;
    use Time::HiRes qw[time];
    use Socket      qw[inet_aton pack_sockaddr_in];
    #
    field $control_url;
    field $service_type;
    field %on;
    field $http;
    field $upnp_available : reader(is_available) = 1;
    field $upnp_device : reader;    # For compatibility, just holds a dummy object or undef

    #
    method on ( $event, $cb ) { push $on{$event}->@*, $cb }

    method _emit ( $event, @args ) {
        for my $cb ( $on{$event}->@* ) {
            try { $cb->(@args) } catch ($e) {
                carp 'Acme::UPnP callback error: ' . $e;
            }
        }
    }
    ADJUST {
        $http = HTTP::Tiny->new( agent => 'Acme-UPnP/1.0', timeout => 3 );
        $upnp_device = bless {}, 'Acme::UPnP::Device';    # Dummy
    }

    method discover_device () {

        # SSDP Search
        my $sock = IO::Socket::INET->new( Proto => 'udp', Broadcast => 1, LocalPort => 0, ) or
            do { carp 'Failed to create UDP socket: ' . $!; return 0 };
        my $msg = join "\r\n", 'M-SEARCH * HTTP/1.1', 'HOST: 239.255.255.250:1900', 'MAN: "ssdp:discover"', 'MX: 2',
            'ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1', '';
        $sock->send( $msg, 0, pack_sockaddr_in( 1900, inet_aton('239.255.255.250') ) );
        my $rin = '';
        vec( $rin, $sock->fileno, 1 ) = 1;
        my $rout;
        my $found_location;
        my $end_time = time + 2.5;

        while ( time < $end_time ) {
            my $left = $end_time - time;
            last if $left <= 0;
            if ( select( $rout = $rin, undef, undef, $left ) ) {
                my $data;
                my $addr = $sock->recv( $data, 4096 );
                if ( defined $data && $data =~ /Location:\s*(https?:\/\/[^\s\r\n]+)/i ) {
                    $found_location = $1;
                    last;
                }
            }
            else {
                last;
            }
        }
        unless ($found_location) {
            $self->_emit('device_not_found');
            return 0;
        }

        # Fetch Description
        my $res = $http->get($found_location);
        unless ( $res->{success} ) {
            $self->_emit( device_not_found => 'Failed to fetch description' );
            return 0;
        }
        my $content = $res->{content};

        # Parse for Service
        my $svc_type;
        my $ctrl_url;

        # Simple regex extraction
        while ( $content =~ m[<service>(.*?)</service>]sg ) {
            my $svc_block = $1;
            if ( $svc_block =~ m[<serviceType>(urn:schemas-upnp-org:service:WAN(?:IP|PPP)Connection:1)</serviceType>]s ) {
                $svc_type = $1;
                if ( $svc_block =~ m[<controlURL>(.*?)</controlURL>]s ) {
                    $ctrl_url = $1;
                    last;
                }
            }
        }
        unless ($ctrl_url) {
            $self->_emit( device_not_found => "No valid WANIP/PPP service" );
            return 0;
        }

        # Handle URL resolution
        if ( $ctrl_url !~ /^http/ ) {
            if ( $ctrl_url =~ m{^/} ) {
                if ( $found_location =~ m[^(https?:\/\/[^\/]+)] ) {
                    $ctrl_url = $1 . $ctrl_url;
                }
            }
            else {
                # Base URL?
                if ( $content =~ m[<URLBase>(.*?)</URLBase>]s ) {
                    my $base = $1;
                    $base =~ s/\/$//;    # strip trailing slash
                    $ctrl_url = "$base/$ctrl_url";
                }
                else {
                    # Relative to location
                    my $base = $found_location;
                    $base =~ s/[^\/]+$//;    # remove filename
                    $ctrl_url = $base . $ctrl_url;
                }
            }
        }
        $control_url  = $ctrl_url;
        $service_type = $svc_type;
        $self->_emit( device_found => { name => 'UPnP Gateway' } );
        return 1;
    }

    method map_port ( $int_port, $ext_port, $proto, $desc ) {
        return 0 unless $control_url;
        my $local_ip = $self->_get_local_ip();
        my $args     = {
            NewRemoteHost             => '',
            NewExternalPort           => $ext_port,
            NewProtocol               => $proto,
            NewInternalPort           => $int_port,
            NewInternalClient         => $local_ip,
            NewEnabled                => 1,
            NewPortMappingDescription => $desc,
            NewLeaseDuration          => 0
        };
        if ( $self->_send_soap( AddPortMapping => $args ) ) {
            $self->_emit( map_success => { int_p => $int_port, ext_p => $ext_port, proto => $proto, desc => $desc } );
            return 1;
        }
        else {
            $self->_emit( map_failed => { err_c => 500, err_d => 'SOAP Failed' } );
            return 0;
        }
    }

    method unmap_port ( $ext_port, $proto ) {
        return 0 unless $control_url;
        my $args = { NewRemoteHost => '', NewExternalPort => $ext_port, NewProtocol => $proto };
        if ( $self->_send_soap( DeletePortMapping => $args ) ) {
            $self->_emit( unmap_success => { ext_p => $ext_port, proto => $proto } );
            return 1;
        }
        $self->_emit( unmap_failed => { err_c => 500, err_d => 'SOAP Failed' } );
        return 0;
    }

    method get_external_ip () {
        return undef unless $control_url;
        my $action = 'GetExternalIPAddress';
        my $res    = $self->_send_soap_response( $action, {} );
        return $1 if $res && $res =~ m{<NewExternalIPAddress>(.*?)</NewExternalIPAddress>}s;
        return undef;
    }

    method _send_soap ( $action, $args ) {
        return defined $self->_send_soap_response( $action, $args );
    }

    method _send_soap_response ( $action, $args ) {
        my $body = <<~END;
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                <u:$action xmlns:u="$service_type">
        END
        for my $k ( keys %$args ) {
            $body .= "<$k>" . $args->{$k} . "</$k>\n";
        }
        $body .= <<~END;
                </u:$action>
            </s:Body>
        </s:Envelope>
        END
        my $res = $http->post( $control_url,
            { headers => { 'Content-Type' => 'text/xml; charset="utf-8"', 'SOAPAction' => "\"$service_type#$action\"" }, content => $body } );
        return $res->{success} ? $res->{content} : undef;
    }

    method _get_local_ip () {
        my $sock = IO::Socket::INET->new( Proto => 'udp', PeerAddr => '192.168.1.1', PeerPort => '1' );
        if ($sock) {
            my $addr = $sock->sockhost;
            return $addr;
        }
        '127.0.0.1';
    }
};
#
1;
