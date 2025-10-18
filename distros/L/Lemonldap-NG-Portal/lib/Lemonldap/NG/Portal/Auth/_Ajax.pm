##@file
# Ajax-based authentication methods (SSL, Kerberos, WebAuthn...)
# This class lets you easily implement a Javascript-based authentication
# method.

package Lemonldap::NG::Portal::Auth::_Ajax;

use strict;
use Mouse::Role;
use Lemonldap::NG::Portal::Main::Constants qw(
  PE_OK
  PE_ERROR
);

our $VERSION = '2.22.0';

# addUnauthRoute/addAuthRoute are provided by deriving your plugin from
# 'Lemonldap::NG::Portal::Main::Auth' or 'Lemonldap::NG::Portal::Main::Plugin'

# You must provide an auth_id attribute that returns a simple string
# identifying your plugin, eg: 'ssl', 'krb', ...
# You must also implement an auth_route method that will be served on
# /auth[auth_id]
# The auth_route method validates your JS-supplied challenge, and must call
# ajax_success to return the authentication token
requires qw(auth_id addUnauthRoute addAuthRoute auth_route);

has InitCmd => (
    is      => 'ro',
    default =>
      q@$self->p->setHiddenFormValue( $req, ajax_auth_token => 0, '', 0 )@
);

# Auth Token
has authott => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $ott =
          $_[0]->{p}->loadModule('Lemonldap::NG::Portal::Lib::OneTimeToken');
        $ott->cache(0);
        return $ott;
    }
);

around 'init' => sub {
    my $orig = shift;
    my $self = shift;

    my $route_name = 'auth' . $self->auth_id;

    # Try to avoid a warning in logs
    unless ( $self->p->unAuthRoutes->{GET}->{$route_name} ) {
        $self->addUnauthRoute(
            $route_name => '_auth_route',
            ['GET']
        );

        # Used for session upgrade/reauthn
        $self->addAuthRoute(
            $route_name => '_auth_route',
            ['GET']
        );
    }
    return $self->$orig();
};

sub _auth_route {
    my ( $self, $req, @path ) = @_;

    # Run beforeAuth steps
    $req->steps( [ @{ $self->p->beforeAuth } ] );
    my $res = $self->p->process($req);
    if ( $res && $res > 0 ) {
        $req->wantErrorRender(1);
        return $self->p->doPE($req, $res);
    }

    return $self->auth_route( $req, @path );
}

# You should call this method in your 'extractFormInfo' to validate the
# Authentication token
sub get_auth_token {
    my ( $self, $req, $token_id ) = @_;
    my $token = $self->authott->getToken($token_id);
    if ($token) {
        if ( $token->{type} eq ( 'auth_token_' . $self->auth_id ) ) {
            # Fix #3180
            utf8::downgrade($token->{user});
            return $token;
        }
        else {
            $self->logger->error( "Unexpected token type: " . $token->{type} );
            return;
        }
    }

    $self->logger->error("Could not fetch user token $token_id");
    return;
}

# You should call this method in your auth_route method to create the Authentication token,
# $user is the main identified, that UserDB will lookup. Extra information may
# be stored in the session by setAuthSessionInfo
sub ajax_success {
    my ( $self, $req, $user, $extraInfo ) = @_;
    my $token = $self->authott->createToken( {
            user      => $user,
            type      => 'auth_token_' . $self->auth_id,
            extraInfo => $extraInfo,
        }
    );
    if ($token) {
        return $self->sendJSONresponse(
            $req,
            {
                ajax_auth_token => $token,
                error           => PE_OK,
            }
        );
    }
    else {
        $self->logger->error("Could not create user token for $user");
        $req->wantErrorRender(1);
        return $self->p->doPE($req, PE_ERROR);
    }
}

1;
