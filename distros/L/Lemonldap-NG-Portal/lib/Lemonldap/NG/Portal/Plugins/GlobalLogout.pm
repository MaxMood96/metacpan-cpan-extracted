package Lemonldap::NG::Portal::Plugins::GlobalLogout;

use strict;
use Mouse;
use JSON qw(from_json to_json);
use Time::Local;
use Lemonldap::NG::Common::Session 'id2storage';
use Lemonldap::NG::Portal::Main::Constants qw(
  PE_OK
  PE_ERROR
  PE_NOTOKEN
  PE_TOKENEXPIRED
  PE_SENDRESPONSE
);

our $VERSION = '2.22.0';

extends qw(
  Lemonldap::NG::Portal::Main::Plugin
  Lemonldap::NG::Portal::Lib::OtherSessions
);

# INTERFACE
use constant beforeLogout => 'run';

# INITIALIZATION
has rule => ( is => 'rw', default => sub { 0 } );
has ott => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $ott =
          $_[0]->{p}->loadModule('Lemonldap::NG::Portal::Lib::OneTimeToken');
        $ott->timeout( $_[0]->conf->{formTimeout} );
        return $ott;
    }
);

sub init {
    my ($self) = @_;
    $self->addAuthRoute( globallogout => 'globalLogout', [ 'POST', 'GET' ] );

    # Parse activation rule
    $self->rule(
        $self->p->buildRule( $self->conf->{globalLogoutRule}, 'globalLogout' )
    );
    return 0 unless $self->rule;

    return 1;
}

# RUNNING METHODS
# Look for user active SSO sessions and suggest to close them
sub run {
    my ( $self, $req ) = @_;
    my $user = $req->{userData}->{ $self->conf->{whatToTrace} };

    # Check activation rule
    unless ( $self->rule->( $req, $req->userData ) ) {
        $self->userLogger->info("GlobaLogout not allowed for $user");
        return PE_OK;
    }

    # Looking for active sessions
    my $sessions = $self->activeSessions($req);
    my $nbr      = @{$sessions};
    $self->logger->debug("GlobalLogout: $nbr session(s) found") if $nbr;
    return PE_OK unless ( $nbr > 1 );

    # Force GlobalLogout if timer is disabled
    if ( $req->param('confirm') && $req->param('confirm') == 1
        || !$self->conf->{globalLogoutTimer} )
    {
        my $msg =
          $self->conf->{globalLogoutTimer}
          ? 'GlobalLogout: confirm parameter detected'
          : 'GlobalLogout: timer disabled';
        $self->logger->debug($msg);
        $self->userLogger->info("GlobalLogout: force global logout for $user");
        $nbr = $self->removeOtherActiveSessions( $req, $sessions );
        $self->userLogger->info("$nbr remaining session(s) removed");

        return PE_OK;
    }

    # Prepare token
    my $token = $self->ott->createToken( {
            user     => $user,
            sessions => to_json($sessions)
        }
    );

    # Prepare form
    $self->logger->debug("Prepare global logout confirmation");
    my $tmp = $self->p->sendHtml(
        $req,
        'globallogout',
        params => {
            FORM_ACTION =>
              $self->p->relativeUrl( $req, 'globallogout', { all => 1 } ),
            SESSIONS  => $sessions,
            TOKEN     => $token,
            LOGIN     => $user,
            CUSTOMPRM => $self->conf->{globalLogoutCustomParam}
        }
    );

    $req->response(
        $req->wantJSON
        ? $self->sendJSONresponse( $req,
            { globalLogout => $nbr, confirmationRequired => 1 } )
        : $tmp
    );

    return PE_SENDRESPONSE;
}

sub globalLogout {
    my ( $self, $req ) = @_;
    my $res   = PE_OK;
    my $count = 0;

    if ( $req->param('all') ) {
        if ( my $token = $req->param('token') ) {
            if ( $token = $self->ott->getToken($token) ) {
                my $storeId =
                  $self->conf->{hashedSessionStore}
                  ? id2storage( $req->{userData}->{_session_id} )
                  : $req->{userData}->{_session_id};

                # Read active sessions from token
                my $sessions = eval { from_json( $token->{sessions} ) };
                if ($@) {
                    $self->logger->error(
                        "GlobalLogout: bad encoding in OTT ($@)");
                    $res = PE_ERROR;
                }
                my $as;
                my $user = $token->{user};
                my $req_user =
                  $req->{userData}->{ $self->{conf}->{whatToTrace} };
                if ( $req_user eq $user ) {
                    foreach (@$sessions) {
                        unless (

                            # searchOn() returns sessions indexed by their
                            # storage ID, then it is required to set hashStore
                            # to 0
                            $as = $self->p->getApacheSession(
                                $_->{id}, hashStore => 0,
                            )
                          )
                        {
                            $self->userLogger->info(
                                "GlobalLogout: session $_->{id} expired");
                            next;
                        }
                        unless ( $storeId eq $_->{id} ) {
                            $self->userLogger->info(
                                "Remove \"$user\" session: $_->{id}");
                            $as->remove;
                            $count++;
                        }
                    }
                }
                else {
                    $self->userLogger->warn(
"GlobalLogout called with an invalid token: $req_user is NOT $user"
                    );
                    $res = PE_TOKENEXPIRED;
                }
            }
            else {
                $self->userLogger->error(
                    "GlobalLogout called with an expired token");
                $res = PE_TOKENEXPIRED;
            }
        }
        else {
            $self->userLogger->error('GlobalLogout called without token');
            $res = PE_NOTOKEN;
        }
    }

    return $self->p->doPE( $req, $res ) if $res;
    $self->userLogger->info("$count remaining session(s) removed");
    return $self->p->do( $req, [ 'authLogout', 'deleteSession' ] );
}

sub activeSessions {
    my ( $self, $req ) = @_;
    my $activeSessions = [];
    my $sessions       = {};
    my $user           = $req->{userData}->{ $self->conf->{whatToTrace} };
    my $customParam    = $self->conf->{globalLogoutCustomParam} || '';

    # Try to retrieve sessions from sessions DB
    if ($user) {
        $self->logger->debug('Try to retrieve sessions from DB');
        my $moduleOptions = $self->conf->{globalStorageOptions} || {};
        $moduleOptions->{backend} = $self->conf->{globalStorage};
        $self->logger->debug("Looking for \"$user\" sessions...");
        $sessions =
          $self->module->searchOn( $moduleOptions, $self->conf->{whatToTrace},
            $user );

        $self->logger->debug('Skip non-SSO session(s)...');
        my $other = 0;
        foreach ( keys %$sessions ) {
            unless ( $sessions->{$_}->{_session_kind} eq 'SSO' ) {
                delete $sessions->{$_};
                $other++;
            }
        }
        $self->logger->info("$other non-SSO session(s) skipped")
          if $other;

        $self->logger->debug('Build an array ref with sessions info...');
        @$activeSessions =
          map {
            my $epoch;
            my $regex = '^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$';
            if ( $_->{startTime} =~ /$regex/ ) {
                $epoch = timelocal( $6, $5, $4, $3, $2 - 1, $1 );
                $_->{startTime} = $epoch;
            }
            else {
                delete $_->{startTime};
            }
            if ( $_->{updateTime} ) {
                if ( $_->{updateTime} =~ /$regex/ ) {

                    $epoch = timelocal( $6, $5, $4, $3, $2 - 1, $1 );
                    $_->{updateTime} = $epoch;
                }
                else {
                    delete $_->{updateTime};
                }
            }
            $_;
          }
          sort { $b->{startTime} cmp $a->{startTime} } map {
            {
                id          => $_,
                customParam => $sessions->{$_}->{$customParam},
                ipAddr      => $sessions->{$_}->{ipAddr},
                authLevel   => $sessions->{$_}->{authenticationLevel},
                startTime   => $sessions->{$_}->{_startTime},
                updateTime  => $sessions->{$_}->{_updateTime}
            };
          } keys %$sessions;
    }

    return $activeSessions;
}

sub removeOtherActiveSessions {
    my ( $self, $req, $sessions ) = @_;
    my $count = 0;
    my $as;

    my $storeId =
      $self->conf->{hashedSessionStore}
      ? id2storage( $req->{userData}->{_session_id} )
      : $req->{userData}->{_session_id};
    foreach (@$sessions) {

        # searchOn() returns sessions indexed by their storage ID, then
        # it is required to set hashStore to 0
        unless ( $as = $self->p->getApacheSession( $_->{id}, hashStore => 0, ) )
        {
            $self->userLogger->info("GlobalLogout: session $_->{id} expired");
            next;
        }
        unless ( $storeId eq $_->{id} ) {
            $self->userLogger->info(
"Remove \"$req->{userData}->{ $self->conf->{whatToTrace} }\" session: $_->{id}"
            );
            $as->remove;
            $count++;
        }
    }

    return $count;
}

1;
