package Lemonldap::NG::Handler::Lib::PSGI;

use strict;
use Mouse;

#use Lemonldap::NG::Handler::Main qw(:jailSharedVars);

our $VERSION = '2.22.0';

has protection => ( is => 'rw', isa => 'Str' );
has rule       => ( is => 'rw', isa => 'Str' );
has api        => ( is => 'rw', isa => 'Str' );

## @method boolean init($args)
# Initalize main handler
sub init {
    my ( $self, $args ) = @_;
    eval { $self->api->init($args) };
    if ( $@ and not( $args->{protection} and $args->{protection} eq 'none' ) ) {
        $self->error($@);
        return 0;
    }
    unless ( $self->api->checkConf($self)
        or ( $args->{protection} and $args->{protection} eq 'none' ) )
    {
        $self->error(
            "Unable to protect this server ($Lemonldap::NG::Common::Conf::msg)"
        );
        return 0;
    }

    eval { $self->portal( $self->api->tsv->{portal}->() ) };
    my $rule =
      $args->{protection} || $self->api->localConfig->{protection} || '';
    $self->rule(
        $rule eq 'authenticate' ? 1 : $rule eq 'manager' ? '' : $rule );
    return 1;
}

## @methodi void _run()
# Check if protecton is activated then return a code ref that will launch
# _authAndTrace() if protection in on or handler() else
#@return code-ref
sub _run {
    my $self = shift;

    # Override _run() only if protection != 'none'
    if ( !$self->rule or $self->rule ne 'none' ) {
        $self->logger->debug('PSGI app is protected');

        # Handle requests
        # Developers, be careful: Only this part is executed at each request
        return $self->psgiAdapter(
            sub {
                return $self->_authAndTrace( $_[0] );
            }
        );
    }

    else {
        $self->logger->debug('PSGI app is not protected');

        # Check if main handler initialization has been done
        unless ( $self->api->tsv ) {
            $self->logger->debug('Checking conf');
            eval { $self->api->checkConf() };
            $self->logger->error($@) if ($@);
        }

        # Handle unprotected requests
        return $self->psgiAdapter(
            sub {
                my $req = $_[0];
                my $res = $self->handler($req);
                push @{ $res->[1] }, $req->spliceHdrs;
                return $res;
            }
        );
    }
}

sub reload {
    my ( $class, $args ) = @_;
    $args //= {};
    my $self = $class->new($args);
    $self->init($args);

    # Check if main handler initialization has been done
    unless ( %{ $self->api->tsv } ) {
        eval { $self->api->checkConf() };
        $self->logger->error($@) if ($@);
    }
    return $self->psgiAdapter(
        sub {
            my $req = $_[0];
            $self->api->reload($req);
            return [ 200, [ $req->spliceHdrs ], [ $req->{respBody} ] ];
        }
    );
}

## @method private PSGI-Response _authAndTrace($req)
# Launch $self->api::run() and then handler() if
# response is 200.
sub _authAndTrace {
    my ( $self, $req, $noCall ) = @_;
    unless ( eval { $self->api->tsv->{portal} } ) {
        $self->api->checkConf(1);
    }

    # TODO: handle types
    my $type = $self->api->checkType($req);
    if ( my $t = $req->env->{VHOSTTYPE} ) {
        $type = $t;
    }
    my $tmp = $self->api;
    $tmp =~ s/::\w+$/::/;
    $type = $tmp . $type;
    Lemonldap::NG::Handler::Main->buildAndLoadType($type);
    die $@ if ($@);
    my ( $res, $session ) = $type->run( $req, $self->{rule} );
    my $portal = eval { $type->tsv->{portal}->($req) };
    $self->logger->warn($@)  if $@;

    if ( $res < 300 ) {
        if ($noCall) {
            return [ $res, [ $req->spliceHdrs ], [] ];
        }
        else {
            $self->logger->debug('User authenticated, calling handler()');
            $res = $self->handler($req);
            push @{ $res->[1] }, $req->spliceHdrs;
            return $res;
        }
    }
    elsif ( $res < 400 ) {
        return [ $res, [ $req->spliceHdrs ], [] ];
    }
    else {
        my $s = ( $portal ? $portal . "/lmerror/$res" : '' );
        $s =
            '<html><head><title>Redirection</title></head><body>'
          . qq{<script type="text/javascript">window.location='$s'</script>}
          . '<h1>Please wait</h1>'
          . qq{<p>An error occurs, you're going to be redirected to <a href="$s">$s</a>.</p>}
          . '</body></html>';
        return [
            $res,
            [
                $req->spliceHdrs,
                'Content-Type'   => 'text/html',
                'Content-Length' => length $s
            ],
            [$s]
        ];
    }
}

## @method hashRef user()
# @return hash of user data
sub user {
    my ( $self, $req ) = @_;
    return $req->userData
      || { $Lemonldap::NG::Handler::Main::tsv->{whatToTrace}
          || _whatToTrace => 'anonymous' };
}

## @method hashRef custom()
# @return hash of custom data
sub custom {
    my ( $self, $req ) = @_;
    return { $Lemonldap::NG::Handler::Main::tsv->{customToTrace} };
}

## @method string userId()
# @return user identifier to log
sub userId {
    my ( $self, $req ) = @_;
    my $userId =
      $req->userData->{ $Lemonldap::NG::Handler::Main::tsv->{whatToTrace}
          || '_whatToTrace' }
      || $req->userData->{'_user'}    # Fix 2377
      || 'anonymous';

    $self->logger->debug("Returned userId: $userId");
    return $userId;
}

## @method boolean group(string group)
# @param $group name of the Lemonldap::NG group to test
# @return boolean : true if user is in this group
sub group {
    my ( $self, $req, $group ) = @_;
    return () unless ( $req->userData->{groups} );
    return ( $req->userData->{groups} =~ /\b$group\b/ );
}

## @method PSGI::Response sendError($req,$err,$code)
# Add user id to $err before calling Lemonldap::NG::Common::PSGI::sendError()
# @param $req Lemonldap::NG::Common::PSGI::Request
# @param $err String to push
# @code int HTTP error code (default to 500)
sub sendError {
    my ( $self, $req, $err, $code ) = @_;
    $err ||= $req->error;
    $self->logger->warn( '[' . $self->userId($req) . "] $err" );
    return $self->Lemonldap::NG::Common::PSGI::sendError( $req, $err, $code );
}

1;
