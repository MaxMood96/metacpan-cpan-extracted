
package AuthCAS;

use strict;
use vars qw( $VERSION);

$VERSION = '1.7';

=encoding utf8

=head1 NAME

AuthCAS - Client library for JA-SIG CAS 2.0 authentication server

=head1 VERSION

Version 1.7

=head1 DESCRIPTION

AuthCAS aims at providing a Perl API to JA-SIG Central Authentication System (CAS). 
Only a basic Perl library is provided with CAS whereas AuthCAS is a full object-oriented library. 

=head1 PREREQUISITES

This script requires IO::Socket::SSL and LWP::UserAgent

=head1 SYNOPSIS

  A simple example with a direct CAS authentication

  use AuthCAS;
  my $cas = new AuthCAS(casUrl => 'https://cas.myserver, 
		    CAFile => '/etc/httpd/conf/ssl.crt/ca-bundle.crt',
		    );

  my $login_url = $cas->getServerLoginURL('http://myserver/app.cgi');

  ## The user should be redirected to the $login_url
  ## When coming back from the CAS server a ticket is provided in the QUERY_STRING

  ## $ST should contain the receaved Service Ticket
  my $user = $cas->validateST('http://myserver/app.cgi', $ST);

  printf "User authenticated as %s\n", $user;


  In the following example a proxy is requesting a Proxy Ticket for the target application

  $cas->proxyMode(pgtFile => '/tmp/pgt.txt',
	          pgtCallbackUrl => 'https://myserver/proxy.cgi?callback=1
		  );
  
  ## Same as before but the URL is the proxy URL
  my $login_url = $cas->getServerLoginURL('http://myserver/proxy.cgi');

  ## Like in the previous example we should receave a $ST

  my $user = $cas->validateST('http://myserver/proxy.cgi', $ST);

  ## Process errors
  printf STDERR "Error: %s\n", &AuthCAS::get_errors() unless (defined $user);

  ## Now we request a Proxy Ticket for the target application
  my $PT = $cas->retrievePT('http://myserver/app.cgi');
    
  ## This piece of code is executed by the target application
  ## It received a Proxy Ticket from the proxy
  my ($user, @proxies) = $cas->validatePT('http://myserver/app.cgi', $PT);

  printf "User authenticated as %s via %s proxies\n", $user, join(',',@proxies);


=head1 DESCRIPTION

Jasig CAS is Yale University's web authentication system, heavily inspired by Kerberos.
Release 2.0 of CAS provides "proxied credential" feature that allows authentication
tickets to be carried by intermediate applications (Portals for instance), they are
called proxy.

This AuthCAS Perl module provides required subroutines to validate and retrieve CAS tickets.

=cut

my @ISA    = qw(Exporter);
my @EXPORT = qw($errors);

my $errors;

use Carp;

=pod

=head2 new

  my $cas = new AuthCAS(
		    casUrl => 'https://cas.myserver', 
		    CAFile => '/etc/httpd/conf/ssl.crt/ca-bundle.crt',
		    );

The C<new> constructor lets you create a new B<AuthCAS> object.

=over

=item casUrl - REQUIRED

=item CAFile

=item CAPath

=item loginPath - '/login'

=item logoutPath - '/logout'

=item serviceValidatePath - '/serviceValidate'

=item proxyPath - '/proxy'

=item proxyValidatePath - '/proxyValidate'

=item SSL_version - unset

Sets the version of the SSL protocol used to transmit data. If the default causes connection issues, setting it to 'SSLv3' may help.
see the documentation for L<IO::Socket::SSL/"METHODS"> for more information
see L<http://www.perlmonks.org/?node_id=746493> for more details.

=back

Returns a new B<AuthCAS> or dies on error.

=cut

sub new {
    my ( $pkg, %param ) = @_;
    my $cas_server = {
        url    => $param{'casUrl'},
        CAFile => $param{'CAFile'},
        CAPath => $param{'CAPath'},

        loginPath  => $param{'loginPath'}  || '/login',
        logoutPath => $param{'logoutPath'} || '/logout',
        serviceValidatePath => $param{'serviceValidatePath'}
          || '/serviceValidate',
        proxyPath         => $param{'proxyPath'}         || '/proxy',
        proxyValidatePath => $param{'proxyValidatePath'} || '/proxyValidate',
        SSL_version       => $param{SSL_version},
    };

    bless $cas_server, $pkg;

    return $cas_server;
}

=pod

=head2 get_errors

Return module errors

=cut

sub get_errors {
    return $errors;
}

=pod

=head2 proxyMode

Use the CAS object as a proxy


=over

=item pgtFile
=item pgtCallbackUrl

=back


=cut

sub proxyMode {
    my $self  = shift;
    my %param = @_;

    $self->{'pgtFile'}        = $param{'pgtFile'};
    $self->{'pgtCallbackUrl'} = $param{'pgtCallbackUrl'};
    $self->{'proxy'}          = 1;

    return 1;
}

## Escape dangerous chars in URLS
sub _escape_chars {
    my $s = shift;

    ## Escape chars
    ##  !"#$%&'()+,:;<=>?[] AND accented chars
    ## escape % first
#    foreach my $i (0x25,0x20..0x24,0x26..0x2c,0x3a..0x3f,0x5b,0x5d,0x80..0x9f,0xa0..0xff) {
    foreach my $i (0x26) {
        my $hex_i = sprintf "%lx", $i;
        $s =~ s/\x$hex_i/%$hex_i/g;
    }

    return $s;
}

=pod

=head2 dump_var


=cut

sub dump_var {
    my ( $var, $level, $fd ) = @_;

    if ( ref($var) ) {
        if ( ref($var) eq 'ARRAY' ) {
            foreach my $index ( 0 .. $#{$var} ) {
                print $fd "\t" x $level . $index . "\n";
                &dump_var( $var->[$index], $level + 1, $fd );
            }
        }
        elsif ( ref($var) eq 'HASH' ) {
            foreach my $key ( sort keys %{$var} ) {
                print $fd "\t" x $level . '_' . $key . '_' . "\n";
                &dump_var( $var->{$key}, $level + 1, $fd );
            }
        }
    }
    else {
        if ( defined $var ) {
            print $fd "\t" x $level . "'$var'" . "\n";
        }
        else {
            print $fd "\t" x $level . "UNDEF\n";
        }
    }
}

## Parse an HTTP URL
sub _parse_url {
    my $url = shift;

    my ( $host, $port, $path );

    if ( $url =~ /^(https?):\/\/([^:\/]+)(:(\d+))?(.*)$/ ) {
        $host = $2;
        $path = $5;
        if ( $1 eq 'http' ) {
            $port = $4 || 80;
        }
        elsif ( $1 eq 'https' ) {
            $port = $4 || 443;
        }
        else {
            $errors = sprintf "Unknown protocol '%s'\n", $1;
            return undef;
        }
    }
    else {
        $errors = sprintf "Unable to parse URL '%s'\n", $url;
        return undef;
    }

    return ( $host, $port, $path );
}

## Simple XML parser
sub _parse_xml {
    my $data = shift;

    my %xml_struct;

    while ( $data =~ /^<([^\s>]+)(\s+[^\s>]+)*>([\s\S\n]*)(<\/\1>)/m ) {
        my ( $new_tag, $new_data ) = ( $1, $3 );
        chomp $new_data;
        $new_data =~ s/^[\s\n]+//m;
        $data     =~ s/^<$new_tag(\s+[^\s>]+)*>([\s\S\n]*)(<\/$new_tag>)//m;
        $data     =~ s/^[\s\n]+//m;

        ## Check if data still includes XML tags
        my $struct;
        if ( $new_data =~ /^<([^\s>]+)(\s+[^\s>]+)*>([\s\S\n]*)(<\/\1>)/m ) {
            $struct = &_parse_xml($new_data);
        }
        else {
            $struct = $new_data;
        }
        push @{ $xml_struct{$new_tag} }, $struct;
    }

    return \%xml_struct;
}

=pod

=head2 getServerLoginURL($service)

Returns a URL that you can redirect the browser to, which includes the URL to return to

TODO: it escapes the return URL, but I've noticed some issues with more complicated URL's

=cut

sub getServerLoginURL {
    my $self    = shift;
    my $service = shift;

    return
        $self->{'url'}
      . $self->{'loginPath'}
      . '?service='
      . &_escape_chars($service);
}

=pod

=head2 getServerLoginGatewayURL($service)

Returns non-blocking login URL
ie: if user is logged in, return the ticket, otherwise do not prompt for login

=cut

sub getServerLoginGatewayURL {
    my $self    = shift;
    my $service = shift;

    return
        $self->{'url'}
      . $self->{'loginPath'}
      . '?service='
      . &_escape_chars($service)
      . '&gateway=1';
}

=pod

=head2 getServerLogoutURL($service)

Return logout URL
After logout user is redirected back to the application

=cut

sub getServerLogoutURL {
    my $self    = shift;
    my $service = shift;

    return
        $self->{'url'}
      . $self->{'logoutPath'}
      . '?service='
      . &_escape_chars($service)
      . '&gateway=1';
}

=pod

=head2 getServerServiceValidateURL($service, $ticket, $pgtUrl)

Returns 

=cut

sub getServerServiceValidateURL {
    my $self    = shift;
    my $service = shift;
    my $ticket  = shift;
    my $pgtUrl  = shift;

    my $query_string =
      'service=' . &_escape_chars($service) . '&ticket=' . $ticket;
    if ( defined $pgtUrl ) {
        $query_string .= '&pgtUrl=' . &_escape_chars($pgtUrl);
    }

    ## URL was /validate with CAS 1.0
    return
        $self->{'url'}
      . $self->{'serviceValidatePath'} . '?'
      . $query_string;
}

=pod

=head2 getServerProxyURL($targetService, $pgt)

Returns 

=cut

sub getServerProxyURL {
    my $self          = shift;
    my $targetService = shift;
    my $pgt           = shift;

    return
        $self->{'url'}
      . $self->{'proxyPath'}
      . '?targetService='
      . &_escape_chars($targetService) . '&pgt='
      . &_escape_chars($pgt);
}

=pod

=head2 getServerProxyValidateURL($service, $ticket)

Returns 

=cut

sub getServerProxyValidateURL {
    my $self    = shift;
    my $service = shift;
    my $ticket  = shift;

    return
        $self->{'url'}
      . $self->{'proxyValidatePath'}
      . '?service='
      . &_escape_chars($service)
      . '&ticket='
      . &_escape_chars($ticket);

}

=pod

=head2 validateST($service, $ticket)

Validate a Service Ticket
Also used to get a PGT


Returns the login that created the ticket, if the ticket is valid for that $service URL

returns undef if the ticket is not valid.

=cut

sub validateST {
    my $self    = shift;
    my $service = shift;
    my $ticket  = shift;
    
    if (!defined($service)) {
        $errors = 'Need a service url to validate ticket.';
        return undef;
    }
    if (!defined($ticket)) {
        $errors = 'No ticket to validate.';
        return undef;
    }

    my $pgtUrl = $self->{'pgtCallbackUrl'};

    my $xml =
      $self->callCAS(
        $self->getServerServiceValidateURL( $service, $ticket, $pgtUrl ) );

    if ( defined $xml->{'cas:serviceResponse'}[0]{'cas:authenticationFailure'} )
    {
        $errors = sprintf "Failed to validate Service Ticket %s : %s\n",
          $ticket,
          $xml->{'cas:serviceResponse'}[0]{'cas:authenticationFailure'}[0];
        return undef;
    }

    my $user =
      $xml->{'cas:serviceResponse'}[0]{'cas:authenticationSuccess'}[0]
      {'cas:user'}[0];

    ## If in Proxy mode, also retreave a PGT
    if ( $self->{'proxy'} ) {
        my $pgtIou;
        if (
            defined $xml->{'cas:serviceResponse'}[0]
            {'cas:authenticationSuccess'}[0]{'cas:proxyGrantingTicket'} )
        {
            $pgtIou =
              $xml->{'cas:serviceResponse'}[0]{'cas:authenticationSuccess'}[0]
              {'cas:proxyGrantingTicket'}[0];
        }

        unless ( defined $self->{'pgtFile'} ) {
            $errors = sprintf "pgtFile not defined\n";
            return undef;
        }

        ## Check stored PGT
        unless ( open STORE, $self->{'pgtFile'} ) {
            $errors = sprintf "Unable to read %s\n", $self->{'pgtFile'};
            return undef;
        }

        my $pgtId;
        while (<STORE>) {
            if (/^$pgtIou\s+(.+)$/) {
                $pgtId = $1;
                last;
            }
        }

        $self->{'pgtId'} = $pgtId;
    }

    return ($user);
}

=pod

=head2 validatePT($service, $ticket)

Validate a Proxy Ticket

Returns the login that created the ticket, if the ticket is valid for that $service URL, 
    and a list of Proxies used.
    
    user returned == undef if its not a valid ticket

=cut

sub validatePT {
    my $self    = shift;
    my $service = shift;
    my $ticket  = shift;

    if (!defined($service)) {
        $errors = 'Need a service url to validate ticket.';
        return undef;
    }
    if (!defined($ticket)) {
        $errors = 'No ticket to validate.';
        return undef;
    }

    my $xml =
      $self->callCAS( $self->getServerProxyValidateURL( $service, $ticket ) );

    if ( defined $xml->{'cas:serviceResponse'}[0]{'cas:authenticationFailure'} )
    {
        $errors = sprintf "Failed to validate Proxy Ticket %s : %s\n", $ticket,
          $xml->{'cas:serviceResponse'}[0]{'cas:authenticationFailure'}[0];
        return undef;
    }

    my $user =
      $xml->{'cas:serviceResponse'}[0]{'cas:authenticationSuccess'}[0]
      {'cas:user'}[0];

    my @proxies;
    if (
        defined $xml->{'cas:serviceResponse'}[0]{'cas:authenticationSuccess'}[0]
        {'cas:proxies'} )
    {
        @proxies =
          @{ $xml->{'cas:serviceResponse'}[0]{'cas:authenticationSuccess'}[0]
              {'cas:proxies'}[0]{'cas:proxy'} };
    }

    return ( $user, @proxies );
}

=pod

=head2 callCAS($url)

## Access a CAS URL and parses received XML

Returns 

=cut

sub callCAS {
    my $self = shift;
    my $url  = shift;

    my ( $host, $port, $path ) = &_parse_url($url);

    my $xml = get_https2(
        $host, $port, $path,
        {
            'cafile'      => $self->{'CAFile'},
            'capath'      => $self->{'CAPath'},
            'SSL_version' => $self->{'SSL_version'}
        }
    );

#use Data::Dumper; die '--'.$#$xml.': '.Dumper($xml);

    unless ($xml && $#$xml >= 0) {
        warn $errors;
        return undef;
    }

    ## Skip HTTP header fields
    my $line = shift @$xml;
    while ( $line !~ /^\s*$/ ) {
        $line = shift @$xml;
    }

    return &_parse_xml( join( '', @$xml ) );
}

=pod

=head2 storePGT($pgtIou, $pgtId)

=cut

sub storePGT {
    my $self   = shift;
    my $pgtIou = shift;
    my $pgtId  = shift;

    unless ( open STORE, ">>$self->{'pgtFile'}" ) {
        $errors = sprintf "Unable to write to %s\n", $self->{'pgtFile'};
        return undef;
    }
    printf STORE "%s\t%s\n", $pgtIou, $pgtId;
    close STORE;

    return 1;
}

=pod

=head2 retrievePT($service)

Returns 

=cut

sub retrievePT {
    my $self    = shift;
    my $service = shift;

    my $xml =
      $self->callCAS( $self->getServerProxyURL( $service, $self->{'pgtId'} ) );

    if ( defined $xml->{'cas:serviceResponse'}[0]{'cas:proxyFailure'} ) {
        $errors = sprintf "Failed to get PT : %s\n",
          $xml->{'cas:serviceResponse'}[0]{'cas:proxyFailure'}[0];
        return undef;
    }

    if (
        defined $xml->{'cas:serviceResponse'}[0]{'cas:proxySuccess'}[0]
        {'cas:proxyTicket'} )
    {
        return $xml->{'cas:serviceResponse'}[0]{'cas:proxySuccess'}[0]
          {'cas:proxyTicket'}[0];
    }

    return undef;
}

=pod

=head2 get_https2

request a document using https, return status and content

Sven suspects this is intended to be private.

Returns 

=cut

sub get_https2 {
    my $host = shift;
    my $port = shift;
    my $path = shift;

    my $ssl_data = shift;

    my $trusted_ca_file = $ssl_data->{'cafile'};
    my $trusted_ca_path = $ssl_data->{'capath'};

    if (   ( $trusted_ca_file && !( -r $trusted_ca_file ) )
        || ( $trusted_ca_path && !( -d $trusted_ca_path ) ) )
    {
        $errors = sprintf
"error : incorrect access to cafile ".($trusted_ca_file||'<empty>')." or capath ".($trusted_ca_path||'<empty>')."\n";
        return undef;
    }

    unless ( eval "require IO::Socket::SSL" ) {
        $errors = sprintf
"Unable to use SSL library, IO::Socket::SSL required, install IO-Socket-SSL (CPAN) first\n";
        return undef;
    }
    require IO::Socket::SSL;

    unless ( eval "require LWP::UserAgent" ) {
        $errors = sprintf
"Unable to use LWP library, LWP::UserAgent required, install LWP (CPAN) first\n";
        return undef;
    }
    require LWP::UserAgent;

    my $ssl_socket;

    my %ssl_options = (
        SSL_use_cert => 0,
        PeerAddr     => $host,
        PeerPort     => $port,
        Proto        => 'tcp',
        Timeout      => '5'
    );

    $ssl_options{'SSL_ca_file'} = $trusted_ca_file if ($trusted_ca_file);
    $ssl_options{'SSL_ca_path'} = $trusted_ca_path if ($trusted_ca_path);

    ## If SSL_ca_file or SSL_ca_path => verify peer certificate
    $ssl_options{'SSL_verify_mode'} = 0x01
      if ( $trusted_ca_file || $trusted_ca_path );

    $ssl_options{'SSL_version'} = $ssl_data->{'SSL_version'}
      if defined( $ssl_data->{'SSL_version'} );

    $ssl_socket = new IO::Socket::SSL(%ssl_options);

    unless ($ssl_socket) {
        $errors = sprintf "error %s unable to connect https://%s:%s/\n",
          &IO::Socket::SSL::errstr, $host, $port;
        return undef;
    }

    my $request = "GET $path HTTP/1.0\r\nHost: $host\r\n\r\n";
    print $ssl_socket "$request";

    my @result;
    while ( my $line = $ssl_socket->getline ) {
        push @result, $line;
    }

    $ssl_socket->close( SSL_no_shutdown => 1 );

    return \@result;
}

=pod

=head1 SEE ALSO

JA-SIG Central Authentication Service L<http://www.jasig.org/cas>

was Yale Central Authentication Service L<http://www.yale.edu/tp/auth/>
 
phpCAS L<http://esup-phpcas.sourceforge.net/>

=head1 COPYRIGHT

Copyright (C) 2003, 2005,2006,2007,2009 Olivier Salaun - Comité Réseau des Universités L<http://www.cru.fr>
              2012 Sven Dowideit - L<mailto:SvenDowideit@fosiki.com>


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

  Olivier Salaun
  Sven Dowideit

=cut

1;

