package DeyeCloud::Client;

=pod #{{{ main documentation section

=head1 B<NAME>

B<DeyeCloud::Client> - perl5 client to Deye Cloud API

=head1 B<DESCRIPTION>

This module implements all operations as described in L<Deye
Cloud developer guide|https://developer.deyecloud.com/api> (and some operations not described).

=head1 B<CAVEATS>

=over 4

=item *

This module requires perl v5.10+ since it uses 'signatures' feature;

=item *

All options and results names have the same names as passed to or returned
by Deye Cloud. I don't like their naming conventions (or rather, the lack
thereof) too. However, they are (partially) described in Deye Cloud developer
guide, so let's assume this is not the worst case.

=back

=head1 B<SYNOPSIS>

    use DeyeCloud::Client;
    
    my $deye = DeyeCloud::Client->new();

    $deye->method('GET');
    $deye->baseurl('https://www.deyecloud.com/device-s');
    my $device = $deye->call('device/originalData', 'deviceId' => $device_id);

    $deye->error
        ? die $deye->errmsg
        : printf "Battery SOC = %.2f\n", $device->{'BMS_SOC'};
    
    # or almost the same using wrapper method:
    
    $device = $deye->status('deviceId' => $device_id);

    $deye->error
        ? die $deye->errmsg
        : printf "Battery SOC = %.2f\n", $device->BMS_SOC;

=cut #}}}

use strict;
use warnings 'FATAL' => 'all';
no warnings qw(experimental::signatures);
use feature qw(signatures);
use parent qw(DeyeCloud::Client::Common);
use boolean qw(:all);

our $VERSION = $DeyeCloud::Client::Common::VERSION;

use Class::XSAccessor {
	'accessors' => [ qw(baseurl errno errmsg method) ],
	'getters' => [ qw(caller headers ua) ]
};
use Data::Dumper;
use DeyeCloud::Client::Device;
use DeyeCloud::Client::Station;
use Digest::SHA qw(sha256_hex);
use HTTP::Request;
use HTTP::Status qw(:constants :is status_message);
use JSON;
use LWP::UserAgent;
use POSIX qw();
use URI qw();
use URI::Escape;

BEGIN {
    require Exporter;
    our @ISA = qw(Exporter DeyeCloud::Client::Common);
    our @EXPORT = qw();
}

=pod

=head1 B<METHODS>

=cut

sub new :prototype($%) ($class, %options) {
    #{{{

=pod

=over 4

=item B<new(OPTIONS)>

B<DeyeCloud::Client> object constructor. Is used as follows:

    my $deye = DeyeCloud::Client->new('token' => 'AUTHORIZATION_TOKEN');

Supported options are:

=over 4

=item B<baseurl> => STRING

API root URI. Depends on which data you want to retrieve (differs for station
and device). Default value is 'https://eu1-developer.deyecloud.com/v1.0',
which is used for new token and station data retrieval.

=item B<method> => STRING

HTTP method will be used to perform Deye Cloud server queries. Depends
on server. Default value is 'POST', which is used for new token and station
data retrieval.

=item B<sslcheck> => BOOLEAN

Perform SSL certificate check (if set to 'true', default) or not.

=item B<timeout> => INTEGER

Cloud server query timeout. Default value is 15 seconds.

=item B<token> => STRING

Authorization token. Can be either set or retrieved later using 'token'
method.

=back

=back

=cut

    $options{'baseurl'}  ||= DeyeCloud::Client::Station::BASEURL;
    $options{'method'}   ||= DeyeCloud::Client::Station::METHOD;
    $options{'sslcheck'} ||= DeyeCloud::Client::Common::SSLCHECK;
    $options{'timeout'}  ||= DeyeCloud::Client::Common::TIMEOUT;
    my $self = bless {
        'baseurl'  => $options{'baseurl'},
        'method'   => $options{'method'},
        'sslcheck' => $options{'sslcheck'},
        'ua'       => LWP::UserAgent->new(
            'default_headers'   => HTTP::Headers->new(),
            'protocols_allowed' => [ qw(https) ],
            'ssl_opts'          => { 'verify_hostname' => $options{'sslcheck'} },
            'timeout'           => $options{'timeout'},
        ),
    }, __PACKAGE__;
    $self->ua->default_header('Accept' => 'application/json');
    $self->ua->default_header('Content-Type' => 'application/json');
    if (defined $options{'token'}) {
        $self->token($options{'token'});
        $self->ua->default_header('Authorization' => 'Bearer ' . $self->token);
    }
    $self->seterror();
    return $self;
} #}}}

sub token :prototype($@) ($self, @options) {
    #{{{

=pod

=over 4

=item B<token(STRING | HASH)>

This method is used for operations with authorization token as follows:

    # Get current authorization token
    #
    my $token = $deye->token();
    
    # Set authorization token to a new value
    #
    $deye->token('AUTHORIZATION_TOKEN');
    
    # Generate and return a new authorization token
    #
    $deye->token(
        'appId'     => 'APPLICATION_ID',
        'appSecret' => 'APPLICATION_SECRET',
        'email'     => 'ACCOUNT_EMAIL',
        'password'  => 'ACCOUNT_PASSWORD',
    );
    $deye->error
        ? die $deye->errmsg
        : printf "%s\n", $deye->token;

Deye Cloud provides a possibility to generate a new token using a phone
number and a country code instead of email, but this way is not implemented
yet.

Pay an attention, that some options are written in lower case and some -
in lower Camel case. Just the way they are named in Deye Cloud developer guide.

Supported options are:

=over 4

=item B<appId> => STRING

Application ID (register new L<here|https://developer.deyecloud.com/app> if you don't have one).

=item B<appSecret> => STRING

Application secret (see 'appId' item).

=item B<email> => STRING

Deye Cloud account email.

=item B<password> => STRING

Deye Cloud account password.

=back

=back

=cut

    if (scalar @options == 0) {
        return $self->{'token'} if defined $self->{'token'};
    } elsif (scalar @options == 1) {
        $self->{'token'} = shift @options;
        $self->ua->default_header('Authorization' => 'Bearer ' . $self->{'token'});
        return $self->{'token'};
    }
    push @options, undef unless scalar @options % 2 == 0;
    my %options = @options;
    unless ($options{'appId'}) {
        $self->seterror(DeyeCloud::Client::Common::E_NOAPPID);
        return undef;
    }
    unless ($options{'appSecret'}) {
        $self->seterror(DeyeCloud::Client::Common::E_NOAPPSECRET);
        return undef;
    }
    unless ($options{'email'}) {
        $self->seterror(DeyeCloud::Client::Common::E_NOACCEMAIL);
        return undef;
    }
    unless ($options{'password'}) {
        $self->seterror(DeyeCloud::Client::Common::E_NOACCPWD);
        return undef;
    }
    $self->seterror();
    my $json = JSON->new->pretty(0);
    my $request = HTTP::Request->new($self->method, $self->baseurl . '/v1.0/account/token?appId=' . $options{'appId'});
    $request->content($json->encode({
        'appSecret' => $options{'appSecret'},
        'email'     => $options{'email'},
        'password'  => lc sha256_hex $options{'password'}
    }));
    my $response = $self->ua->request($request);
    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $payload = {};
        $payload = $json->decode($content);
        unless (defined $payload) {
            $self->seterror(DeyeCloud::Client::Common::E_DECFAILED);
            return undef;
        }
        return $payload;
    } else {
        $self->seterror(
            DeyeCloud::Client::Common::E_REQFAILED,
            $response->code,
            ($response->message || status_message $response->code)
        );
        return undef;
    }
} #}}}

sub call :prototype($$%) ($self, $command, %content) {
    #{{{

=pod

=over 4

=item B<baseurl(STRING)>

This method gets or sets Deye Cloud API server base URL:

    my $baseurl = $deye->baseurl;
    $deye->baseurl('https://eu1-developer.deyecloud.com/v1.0');

=item B<method(STRING)>

Get or set HTTP method used to send query data to Deye Cloud API
servers. Endpoints and appropriate methods are described in Deye
Cloud developer guide.

    my $method = $deye->method;
    $deye->method('GET');

=item B<call(STRING, HASH)>

This is universal method to conversate with Deye Cloud API servers
as follows:

    # Setting API server base URL and method is not required in
    # every case. However, pay an attention that device data
    # retrieval CAN require setting those variables explicitly!
    #
    $deye->baseurl('https://eu1-developer.deyecloud.com/v1.0');
    $deye->method('POST');
    my $data = $deye->call('station/latest', 'stationId' => INTEGER);

Available options list depends on endpoint. Most endpoints are described
in Deye Cloud developer guide.

=back

=cut

    unless ($self->ua->default_header('Authorization')) {
        $self->seterror(DeyeCloud::Client::Common::E_NOTOKEN);
        return undef;
    }
    $self->seterror();
    my $json = JSON->new->pretty(0);
    my $uri = URI->new($self->baseurl);
    my $path = join '/', $uri->path, $command;
    $uri->path($path);
    $uri->query_form(%content) if $self->method eq 'GET';
    my $request = HTTP::Request->new($self->method, $uri);
    $request->content($json->encode({ %content })) if $self->method ne 'GET';
    my $response = $self->ua->request($request);
    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $payload = {};
        $payload = $json->decode($content);
        unless (defined $payload) {
            $self->seterror(DeyeCloud::Client::Common::E_DECFAILED);
            return undef;
        }
        return $payload;
    } else {
        $self->seterror(
            DeyeCloud::Client::Common::E_REQFAILED,
            $response->code,
            ($response->message || HTTP::Status::status_message $response->code)
        );
        return undef;
    }
} #}}}

sub status :prototype($$%) ($self, %options) {
    #{{{

=pod

=over 4

=item B<status(HASH)>

Wrapper method to get latest station or device status. Implicitly sets
the right method and baseurl, both are restored on return. Main difference
between B<call()> and B<status()> methods is that B<call()> returns reference
to a hash and B<status()> returns a blessed reference to a B<DeyeCloud::Client::Device>
or B<DeyeCloud::Client::Station> class object. You can use either a variable name
or a getter method in order to refer to a specific variable:

    my $status = $deye->status('deviceId' => INTEGER);
    
    printf "Grid voltage, L1: %.2f\n", $status->G_V_L1;
    
    # or, the same in another way:
    
    printf "Grid voltage, L1: %.2f\n", $status->{'G_V_L1'};

Available options are:

=over 4

=item B<deviceId> => INTEGER

Deye Cloud device ID.

=item B<stationId> => INTEGER

Deye Cloud station ID.

=back

=back

=cut

    my $status = undef;
    my $baseurl = $self->baseurl;
    my $method = $self->method;
    if (defined $options{'deviceId'}) {
        $self->method(DeyeCloud::Client::Device::METHOD);
        $self->baseurl(DeyeCloud::Client::Device::BASEURL);
        $status = $self->call('device/originalData', %options);
        if ($self->error) {
            $self->baseurl($baseurl);
            $self->method($method);
            return undef;
        }
        $status->{'lastUpdateDateTime'} = POSIX::strftime('%F %T %Z', (localtime $status->{'zd'})[0 .. 5]);
        $status = DeyeCloud::Client::Device->new(%{$status});
    } elsif (defined $options{'stationId'}) {
        $self->method(DeyeCloud::Client::Station::METHOD);
        $self->baseurl(DeyeCloud::Client::Station::BASEURL);
        $status = $self->call('station/latest', %options);
        if ($self->error) {
            $self->baseurl($baseurl);
            $self->method($method);
            return undef;
        }
        $status->{'lastUpdateDateTime'} = POSIX::strftime('%F %T %Z', (localtime $status->{'lastUpdateTime'})[0 .. 5]);
        $status = DeyeCloud::Client::Station->new(%{$status});
    } else {
        $self->seterror(DeyeCloud::Client::Common::E_INVALIDOPTS);
        $self->baseurl($baseurl);
        $self->method($method);
        return undef;
    }
    $self->baseurl($baseurl);
    $self->method($method);
    return $status;
} #}}}

1;

=pod

=over 4

=item B<error()>

Takes no arguments. Returns 'false' if B<DeyeCloud::Client> object is
defined and error flag is not set and 'true' otherwise.

=item B<errno()>

Takes no arguments. Returns error code. 'B<0>' is returned for no error.

=item B<errmsg()>

Takes no arguments. Returns error message. Empty string ('') is
returned for no error.

=item B<seterror(ERROR [, LIST])>

Set or reset (when called with no arguments) error flag, error code and error
message. It is called implicitly when any service method is called and should
not be called explicitly in any circumstances.

=back

=head1 B<AUTHORS>                                                                                                                   
                                                                                                                                    
=over 4                                                                                                                             
                                                                                                                                    
=item Volodymyr Pidgornyi, vpE<lt>atE<gt>dtel-ix.net;                                                                               
                                                                                                                                    
=back                                                                                                                               
                                                                                                                                    
=head1 B<CHANGELOG>

=head3 v0.0.2 - 2026-02-23

=over 4

=item *

Added readable and predictable aliases to device parameters names
(e. g. 'gridV1' instead of 'G_V_L1');

=item *

Minor documentation updates.

=back

=head3 v0.0.1 - 2026-02-22

=over 4

=item *

Initial public release.

=back

=head1 B<TODO>

=over 4

=item *

Add token retrieval using country code / phone number pair in addition
to email.

=back

=head1 B<LINKS>

=over 4

=item L<Deye Cloud developer guide|https://developer.deyecloud.com/api>;

=back

=cut

