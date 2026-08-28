package Business::Payr::Request;

=head1 NAME

Business::Payr::Request - abstract class to handle low level request
traffic to the Payr API, you probably don't need to use this and should
use the main L<Business::Payr> module instead.

=cut

use strict;
use warnings;
use feature qw/ signatures postderef /;

use Moose;
no warnings qw/ experimental::signatures experimental::postderef /;

use Business::Payr::Types;

use Try::Tiny::SmartCatch;
use Mojo::UserAgent;
use Carp qw/ croak /;
use JSON;

my $MAX_REDIRECTS = 5;

=head1 ATTRIBUTES

=over

=item api_token (Str, required)

Your Payr server API token. Included in every request as
C<Authorization: Token E<lt>api_tokenE<gt>>.

=item api_host (Str)

The Payr API hostname. Defaults to C<api.mypayr.co.uk> (production).
Set to C<sandbox-api.mypayr.co.uk> for sandbox testing.

=item iframe_host (Str)

The Payr iframe hostname. Defaults to C<mypayr.co.uk> (production).
Set to C<sandbox.mypayr.co.uk> for sandbox testing.

=back

=cut

has 'api_token' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'api_host' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    default  => sub { 'api.mypayr.co.uk' },
);

has 'iframe_host' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    default  => sub { 'mypayr.co.uk' },
);

has '_ua' => (
    is       => 'ro',
    isa      => 'UserAgent',
    required => 0,
    default  => sub {
        return Mojo::UserAgent->new
            ->max_redirects( $MAX_REDIRECTS )
            ->connect_timeout( 5 )
            ->inactivity_timeout( 5 )
            ->request_timeout( 30 )
        ;
    },
);

=head1 METHODS

=head2 api_post

Performs an authenticated POST request to the given path under the
C</thirdparty> base path. Returns the decoded JSON response on success,
or throws an exception on failure.

    my $res = $self->api_post( '/onboarding/', \%body );

=cut

sub api_post (
    $self,
    $path,
    $http_request_body = undef,
) {
    my $json = $http_request_body
        ? JSON->new->utf8->canonical->encode( $http_request_body )
        : undef;

    return $self->_ua_request(
        "https://" . $self->api_host . "/thirdparty" . $path,
        $json,
        [
            'Authorization' => "Token " . $self->api_token,
        ],
        'POST',
    );
}

sub _ua_request (
    $self,
    $url,
    $body,
    $headers = undef,
    $method  = 'POST',
) {
    my $ua  = $self->_ua;
    my $res = $ua->start( $ua->build_tx(
        $method,
        $url,
        {
            'Accept'       => 'application/json; charset=UTF-8',
            'Content-Type' => 'application/json; charset=UTF-8',
            @{ $headers // [] },
        },
        # Mojo::UserAgent::Transactor::tx calls $self->generators and then the
        # callbacks based on count of @_, and does not expect undef here
        ( defined $body ? ($body) : () ),
    ) )->result;

    # Possibly a redirect loop - this should be very rare
    if ( $res->code == 301 ) {
        croak( "Payr $method $url failed > $MAX_REDIRECTS levels of redirect" );
    }

    my $code = $res->code;

    # No content
    return if $code == 204;

    my $type = $res->headers->content_type;
    croak( "Payr $method $url returned $code with no MIME type" )
        unless defined $type;

    $body = $res->body;

    croak( "Payr $method $url returned $code $type not JSON, status line: "
               . $res->message )
        unless $type =~ m!\Aapplication/json\b!i;

    croak( "Payr $method $url returned $code with an empty body" )
        unless length $body;

    my $res_content = try sub {
        JSON->new->canonical->decode( $body );
    },
    catch_default sub {
        croak( "Payr $method $url returned $code with malformed JSON"
                   . " length @{[ length $body ]}: $_" );
    };

    croak( "Payr $method $url returned $code JSON $res_content" )
        unless ref $res_content eq 'HASH';

    return $res_content
        if $res->is_success;

    # --- Error handling ---
    # Payr has several documented error response formats, try each in turn.

    # Authentication / authorisation errors:
    #   { "detail": "Invalid token." }
    #   { "detail": "Authentication credentials were not provided." }
    if ( my $detail = $res_content->{detail} ) {
        croak( "Payr $method $url returned $code: $detail" );
    }

    # Processing errors:
    #   { "error": "Failed to download agreement document from provided URL" }
    if ( my $error = $res_content->{error} ) {
        croak( "Payr $method $url returned $code: $error" );
    }

    # Field-level validation errors:
    #   { "email": ["This field is required."], "tenant": [...] }
    # or nested within tenant / installment arrays:
    #   { "tenant": [ { "frequency": ["\"weekly\" is not a valid choice."] } ] }
    my @messages;
    for my $field ( sort keys %$res_content ) {
        my $errors = $res_content->{$field};

        # Only treat array values as field-level validation errors.
        # Scalar values do not match any documented Payr validation error
        # format, so skip them here and let them fall through to the generic
        # "unknown JSON keys" fallback below.
        next unless ref $errors eq 'ARRAY';

        for my $err ( @$errors ) {
            if ( ref $err eq 'HASH' ) {
                # Nested validation error (e.g. inside a tenant object)
                for my $nested_field ( sort keys %$err ) {
                    my $nested_errors = $err->{$nested_field};
                    my $msgs = ref $nested_errors
                        ? join( ', ', @$nested_errors )
                        : $nested_errors;
                    push @messages, "$field.$nested_field: $msgs";
                }
            }
            else {
                push @messages, "$field: $err";
            }
        }
    }

    if ( @messages ) {
        croak( "Payr $method $url returned $code: " . join( "; ", @messages ) );
    }

    # Fallback for any undocumented response shape
    croak( "Payr $method $url returned $code with JSON keys "
               . join( ', ', map { "'$_'" } sort keys %$res_content )
               . ' and status line: ' . $res->message );
}

1;

# vim: ts=4:sw=4:et
