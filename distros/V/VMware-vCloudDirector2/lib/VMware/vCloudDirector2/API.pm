package VMware::vCloudDirector2::API;

# ABSTRACT: Module to do stuff!

use strict;
use warnings;
use v5.10;    # needed for state variable

our $VERSION = '0.108'; # VERSION
our $AUTHORITY = 'cpan:NIGELM'; # AUTHORITY

use Moose;
use Method::Signatures;
use MooseX::Types::Path::Tiny qw(Path);
use MooseX::Types::URI qw(Uri);
use Cpanel::JSON::XS;
use LWP::UserAgent::Determined;
use MIME::Base64;
use Mozilla::CA;
use Path::Tiny;
use Ref::Util qw(is_plain_hashref is_plain_arrayref);
use Scalar::Util qw(looks_like_number);
use Syntax::Keyword::Try 0.04;    # Earlier versions throw errors
use VMware::vCloudDirector2::Error;
use VMware::vCloudDirector2::Object;
use XML::Fast qw();               # just for the versions document
use Data::Dump qw(pp);

# ------------------------------------------------------------------------


has hostname   => ( is => 'ro', isa => 'Str',  required => 1 );
has username   => ( is => 'ro', isa => 'Str',  required => 1 );
has password   => ( is => 'ro', isa => 'Str',  required => 1 );
has orgname    => ( is => 'ro', isa => 'Str',  required => 1, default => 'System' );
has ssl_verify => ( is => 'ro', isa => 'Bool', default  => 1 );
has debug      => ( is => 'rw', isa => 'Int',  default  => 0, );
has timeout    => ( is => 'rw', isa => 'Int',  default  => 120 );    # Defaults to 120 seconds
has _debug_trace_directory =>
    ( is => 'ro', isa => Path, coerce => 1, predicate => '_has_debug_trace_directory' );

has default_accept_header => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_default_accept_header',
    clearer => '_clear_default_accept_header',
);

has _base_url => (
    is      => 'ro',
    isa     => Uri,
    lazy    => 1,
    builder => '_build_base_url',
    writer  => '_set_base_url',
    clearer => '_clear_base_url',
);

has ssl_ca_file => (
    is      => 'ro',
    isa     => Path,
    coerce  => 1,
    lazy    => 1,
    builder => '_build_ssl_ca_file'
);

method _build_ssl_ca_file () { return path( Mozilla::CA::SSL_ca_file() ); }
method _build_base_url () { return URI->new( sprintf( 'https://%s/', $self->hostname ) ); }

method _build_default_accept_header () {
    return ( 'application/*+json;version=' . $self->api_version );
}
method _debug (@parameters) { warn join( '', '# ', @parameters, "\n" ) if ( $self->debug ); }

# ------------------------------------------------------------------------

method BUILD ($args) {

    # deal with setting debug if needed
    my $env_debug = $ENV{VCLOUD_API_DEBUG};
    if ( defined($env_debug) ) {
        $self->debug($env_debug) if ( looks_like_number($env_debug) );
    }
}

# ------------------------------------------------------------------------
has _ua => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    clearer => '_clear_ua',
    builder => '_build_ua'
);

has _ua_module_version => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { our $VERSION //= '0.00'; sprintf( '%s/%s', __PACKAGE__, $VERSION ) }
);

method _build_ua () {
    return LWP::UserAgent::Determined->new(
        agent      => $self->_ua_module_version . ' ',
        cookie_jar => {},
        ssl_opts   => { verify_hostname => $self->ssl_verify, SSL_ca_file => $self->ssl_ca_file },
        timeout    => $self->timeout,
        env_proxy  => 1,
    );
}

# ------------------------------------------------------------------------
has _json => (
    is      => 'ro',
    isa     => 'Cpanel::JSON::XS',
    lazy    => 1,
    builder => '_build_json',
);

method _build_json () { return Cpanel::JSON::XS->new->utf8->allow_blessed->convert_blessed; }

# ------------------------------------------------------------------------
method _decode_xml_response ($response) {
    my $content = $response->decoded_content;
    return if ( length($content) == 0 );

    VMware::vCloudDirector2::Error->throw(
        { message => "Not a XML response as expected - $content", response => $response } )
        unless ( $response->content_type() =~ m|\bxml\b| );
    try {
        return unless ( defined($content) and length($content) );
        return XML::Fast::xml2hash($content);
    }
    catch {
        VMware::vCloudDirector::Error->throw(
            {   message  => "XML decode failed - " . join( ' ', $@ ),
                response => $response
            }
        );
    }
}

# ------------------------------------------------------------------------
method _decode_json_response ($response) {
    my $content = $response->decoded_content;
    return if ( length($content) == 0 );

    VMware::vCloudDirector2::Error->throw(
        {   message  => "Not a JSON response as expected - $content",
            response => $response
        }
    ) unless ( $response->content_type() =~ m|\bjson\b| );

    try {
        return unless ( defined($content) and length($content) );
        return $self->_json->decode($content);
    }
    catch {
        VMware::vCloudDirector2::Error->throw(
            {   message  => "JSON decode failed - " . join( ' ', $@ ),
                response => $response
            }
        );
    }
}

# ------------------------------------------------------------------------
method _encode_json_content ($hash) {
    return $self->_json->encode($hash);
}

# ------------------------------------------------------------------------
method _request ($method, $url, $content?, $headers?) {
    my $uri = URI->new_abs( $url, $self->_base_url );
    $self->_debug("API: _request [$method] $uri") if ( $self->debug );

    my $request = HTTP::Request->new( $method => $uri );

    # build headers
    if ( defined $content && length($content) ) {
        $request->content($content);
        $request->header( 'Content-Length', length($content) );
    }
    else {
        $request->header( 'Content-Length', 0 );
    }

    # add any supplied headers
    my $seen_accept;
    if ( defined($headers) ) {
        foreach my $h_name ( keys %{$headers} ) {
            $request->header( $h_name, $headers->{$h_name} );
            $seen_accept = 1 if ( lc($h_name) eq 'accept' );
        }
    }

    # set accept header
    $request->header( 'Accept', $self->default_accept_header ) unless ($seen_accept);

    # set auth header
    $request->header( 'x-vcloud-authorization', $self->authorization_token )
        if ( $self->has_authorization_token );

    # do request
    my $response;
    try { $response = $self->_ua->request($request); }
    catch {
        VMware::vCloudDirector2::Error->throw(
            {   message => "$method request bombed",
                uri     => $uri,
                request => $request,
            }
        );
    }

    # if _debug_trace_directory is set - we dump info from each request out into
    # a pair of files, one with the dumped response object, the other with the content
    if ( $self->_has_debug_trace_directory ) {
        state $xcount = 0;
        die "No trace directory - " . $self->_debug_trace_directory
            unless ( $self->_debug_trace_directory->is_dir );
        $self->_debug_trace_directory->child( sprintf( '%06d.txt', ++$xcount ) )
            ->spew( pp($response) );
        my $ext = ( $response->content_type =~ /json/ ) ? 'json' : 'xml';
        $self->_debug_trace_directory->child( sprintf( '%06d.%s', $xcount, $ext ) )
            ->spew( $response->decoded_content );
    }

    # Throw if this went wrong
    if ( $response->is_error ) {
        my $message = "$method request failed [$uri] - ";
        try {
            my $decoded_response = $self->_decode_json_response($response);
            $message .=
                ( exists( $decoded_response->{message} ) )
                ? $decoded_response->{message}
                : ( 'Unknown after decode: ' . $response->decoded_content );
        }
        catch { $message .= 'Unknown'; }
        VMware::vCloudDirector2::Error->throw(
            {   message  => $message,
                uri      => $uri,
                request  => $request,
                response => $response
            }
        );
    }

    return $response;
}

# ------------------------------------------------------------------------


has api_version => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    clearer => '_clear_api_version',
    builder => '_build_api_version'
);
has _url_login => (
    is      => 'rw',
    isa     => Uri,
    lazy    => 1,
    clearer => '_clear_url_login',
    builder => '_build_url_login'
);
has _url_provider_login => (
    is      => 'rw',
    isa     => Uri,
    lazy    => 1,
    clearer => '_clear_url_provider_login',
    builder => '_build_url_provider_login'
);
has _raw_version => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    clearer => '_clear_raw_version',
    builder => '_build_raw_version'
);
has _raw_version_full => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    clearer => '_clear_raw_version_full',
    builder => '_build_raw_version_full'
);

method _build_api_version () { return $self->_raw_version->{Version}; }
method _build_url_login () { return URI->new( $self->_raw_version->{LoginUrl} ); }

method _build_url_provider_login () {
    return URI->new( $self->_raw_version->{ProviderLoginUrl} || $self->_raw_version->{LoginUrl} );
}

method _build_raw_version () {
    my $hash    = $self->_raw_version_full;
    my $version = 0;
    my $version_block;
    for my $verblock ( @{ $hash->{SupportedVersions}{VersionInfo} } ) {
        next if ( ( $verblock->{-deprecated} || '' ) eq 'true' );
        if ( $verblock->{Version} > $version ) {
            $version_block = $verblock;
            $version       = $verblock->{Version};
        }
    }

    $self->_debug("API: version used: $version") if ( $self->debug );
    die "No valid version block seen" unless ($version_block);

    return $version_block;
}

method _build_raw_version_full () {
    my $response = $self->_request( 'GET', '/api/versions', undef, { Accept => 'text/xml' } );
    return $self->_decode_xml_response($response);
}

# ------------------------ ------------------------------------------------


has authorization_token => (
    is        => 'ro',
    isa       => 'Str',
    writer    => '_set_authorization_token',
    clearer   => '_clear_authorization_token',
    predicate => 'has_authorization_token'
);

has current_session => (
    is        => 'ro',
    isa       => 'Ref',
    clearer   => '_clear_current_session',
    predicate => 'has_current_session',
    lazy      => 1,
    builder   => '_build_current_session'
);

method _build_current_session () {
    my $login_id     = join( '@', $self->username, $self->orgname );
    my $encoded_auth = 'Basic ' . MIME::Base64::encode( join( ':', $login_id, $self->password ) );
    $self->_debug("API: attempting login as: $login_id") if ( $self->debug );
    my $url = ( $self->orgname eq 'System' ) ? $self->_url_provider_login : $self->_url_login;
    my $session;
    my $token;
    if ( $url =~ m|/cloudapi/| ) {
        my $response = $self->_request(
            'POST', $url, undef,
            {   Authorization => $encoded_auth,
                Accept        => sprintf( "application/json;version=%s", $self->api_version )
            }
        );
        $session = $self->_decode_json_response($response);
        $token   = $session->{id};
        $token =~ s/.*://;
        $token =~ tr/-//d;
    }
    else {
        my $response = $self->_request( 'POST', $url, undef, { Authorization => $encoded_auth } );
        $token = $response->header('x-vcloud-authorization');
        ($session) = $self->_build_returned_objects($response);
    }

    $self->_set_authorization_token($token);
    $self->_debug("API: authentication token: $token") if ( $self->debug );

    # we also reset the base url to match the login URL
    ## $self->_set_base_url( $self->_url_login->clone->path('') );

    return $session;
}

method login () { return $self->current_session; }

method logout () {
    if ( $self->has_current_session ) {

        # just do this - it might fail, but little you can do now
        try { $self->DELETE( $self->_url_login ); }
        catch { warn "DELETE of session failed: ", @_; }
    }
    $self->_clear_api_data;
}

# ------------------------------------------------------------------------
method _build_returned_objects ($response) {

    if ( $response->is_success ) {
        $self->_debug("API: building objects") if ( $self->debug );

        my $hash = $self->_decode_json_response($response);
        unless ( defined($hash) ) {
            $self->_debug("API: returned null object") if ( $self->debug );
            return;
        }

        # See if this is a list of things, in which case the type element will
        # be thingList and it will have a set of thing in it
        my $mime_type = $hash->{type};
        unless ( defined($mime_type) ) {
            $mime_type = $response->header('Content-Type');
            $mime_type =~ s/;.*//;
            $hash->{type} = $mime_type;
        }
        my $type       = ( $mime_type =~ m|^application/vnd\..*\.(\w+)\+json$| ) ? $1  : $mime_type;
        my $thing_type = ( substr( $type, -4, 4 ) eq 'List' ) ? substr( $type, 0, -4 ) : $type;

        if (    ( $type ne $thing_type )
            and ( exists( $hash->{$thing_type} ) )
            and is_plain_arrayref( $hash->{$thing_type} ) ) {
            my @thing_objects;
            $self->_debug("API: building a set of [$thing_type] objects") if ( $self->debug );
            foreach my $thing ( $self->_listify( $hash->{$thing_type} ) ) {
                my $object = VMware::vCloudDirector2::Object->new(
                    hash            => $thing,
                    api             => $self,
                    _partial_object => 1
                );
                push @thing_objects, $object;
            }
            return @thing_objects;
        }

        # was not a list of things, so just objectify the one thing here
        else {
            $self->_debug("API: building a single [$thing_type] object") if ( $self->debug );
            return VMware::vCloudDirector2::Object->new(
                hash => $hash,
                api  => $self,
                href => $response->request->uri,
            );
        }
    }

    # there was an error here - so bomb out
    else {
        VMware::vCloudDirector2::Error->throw(
            { message => 'Error reponse passed to object builder', response => $response } );
    }
}

# ------------------------------------------------------------------------


method GET ($url) {
    $self->current_session;    # ensure/force valid session in place
    my $response = $self->_request( 'GET', $url );
    return $self->_build_returned_objects($response);
}

method GET_hash ($url) {
    $self->current_session;    # ensure/force valid session in place
    my $response = $self->_request( 'GET', $url );
    return $self->_decode_json_response($response);
}

method PUT ($url, $hash, $content_type) {
    $self->current_session;    # ensure/force valid session in place
    my $content  = is_plain_hashref($hash) ? $self->_encode_json_content($hash) : $hash;
    my $response = $self->_request( 'PUT', $url, $content, { 'Content-Type' => $content_type } );
    return $self->_build_returned_objects($response);
}

method POST ($url, $hash, $content_type) {
    $self->current_session;    # ensure/force valid session in place
    my $content  = is_plain_hashref($hash) ? $self->_encode_json_content($hash) : $hash;
    my $response = $self->_request( 'POST', $url, $content, { 'Content-Type' => $content_type } );
    return $self->_build_returned_objects($response);
}

method DELETE ($url) {
    $self->current_session;    # ensure/force valid session in place
    my $response = $self->_request( 'DELETE', $url );
    return $self->_build_returned_objects($response);
}

# ------------------------------------------------------------------------


has query_uri => (
    is      => 'ro',
    isa     => Uri,
    lazy    => 1,
    builder => '_build_query_uri',
    clearer => '_clear_query_uri',
);

method _build_query_uri () {
    my @links = $self->current_session->find_links( rel => 'down', type => 'queryList' );
    VMware::vCloudDirector2::Error->throw('Cannot find single query URL')
        unless ( scalar(@links) == 1 );
    return $links[0]->href;
}

# ------------------------------------------------------------------------


method _clear_api_data () {
    $self->_clear_default_accept_header;
    $self->_clear_base_url;
    $self->_clear_ua;
    $self->_clear_api_version;
    $self->_clear_url_login;
    $self->_clear_url_provider_login;
    $self->_clear_raw_version;
    $self->_clear_raw_version_full;
    $self->_clear_authorization_token;
    $self->_clear_current_session;
    $self->_clear_query_uri;
}

# ------------------------------------------------------------------------
method _listify ($thing) { !defined $thing ? () : ( ( ref $thing eq 'ARRAY' ) ? @{$thing} : $thing ) }

# ------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

VMware::vCloudDirector2::API - Module to do stuff!

=head1 VERSION

version 0.108

=head2 Attributes

=head3 hostname

Hostname of the vCloud server.  Must have a vCloud instance listening for https
on port 443.

=head3 username

Username to use to login to vCloud server.

=head3 password

Password to use to login to vCloud server.

=head3 orgname

Org name to use to login to vCloud server - this defaults to C<System>.

=head3 timeout

Command timeout in seconds.  Defaults to 120.

=head3 default_accept_header

The default MIME types to accept.  This is automatically set based on the
information received back from the API versions.

=head3 ssl_verify

Whether to do standard SSL certificate verification.  Defaults to set.

=head3 ssl_ca_file

The SSL CA set to trust packaged in a file.  This defaults to those set in the
L<Mozilla::CA>

=head2 debug

Set debug level.  The higher the debug level, the more chatter is exposed.

Defaults to 0 (no output) unless the environment variable C<VCLOUD_API_DEBUG>
is set to something that is non-zero.  Picked up at create time in C<BUILD()>.

=head2 API SHORTHAND METHODS

=head3 api_version

The C<api_version> holds the version number of the highest discovered non-
deprecated API, it is initialised by connecting to the C</api/versions>
endpoint, and is called implicitly during the login setup.  Once filled the
values are cached.

=head3 authorization_token

The C<authorization_token> holds the vCloud authentication token that has been
handed out.  It is set by L<login>, and can be tested for by using the
predicate C<has_authorization_token>.

=head3 current_session

The current session object for this login.  Attempting to access this forces a
login and creation of a current session.

=head3 login

Returns the L<current_session> which co-incidently forces a login.

=head3 logout

If there is a current session, DELETEs it, and clears the current session state
data.

=head3 GET ($url)

Forces a session establishment, and does a GET operation on the given URL,
returning the objects that were built.

=head3 GET_hash ($url)

Forces a session establishment, and does a GET operation on the given URL,
returning the JSON equivalent hash that was built.

=head3 PUT ($url, $hash, $content_type)

Forces a session establishment, and does a PUT operation on the given URL,
passing the JSON string or encoded hash, returning the objects that were built.

=head3 POST ($url, $hash, $content_type)

Forces a session establishment, and does a POST operation on the given URL,
passing the JSON string or encoded hash, returning the objects that were built.

=head3 DELETE ($url)

Forces a session establishment, and does a DELETE operation on the given URL,
returning the objects that were built.

=head3 query_uri

Returns the URI for query operations, as taken from the initial session object.

=head2 _clear_api_data

Clears out all the API state data, including the current login state.  This is
not intended to be used from outside the module, and will completely trash the
current state requiring a new login.  The basic information passed at object
construction time is not deleted, so a new session could be created.

=head1 AUTHOR

Nigel Metheringham <nigelm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Nigel Metheringham.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
