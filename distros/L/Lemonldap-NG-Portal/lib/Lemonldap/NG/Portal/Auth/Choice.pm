package Lemonldap::NG::Portal::Auth::Choice;

use strict;
use Mouse;
use Lemonldap::NG::Portal::Main::Constants qw(PE_OK PE_FIRSTACCESS PE_ERROR);

our $VERSION = '2.17.0';

extends 'Lemonldap::NG::Portal::Lib::Choice';

# INITIALIZATION

sub init {
    return $_[0]->SUPER::init(0);
}

# RUNNING METHODS

sub _authCancel {
    my ( $self, $req ) = @_;
    delete $req->pdata->{_choice};
    return $self->SUPER::_authCancel($req);
}

sub extractFormInfo {
    my ( $self, $req ) = @_;

    $self->logger->debug( "Send init/script -> " . $req->data->{customScript} )
      if $req->data->{customScript};
    unless ( $self->checkChoice($req) ) {
        $self->setSecurity($req);
        return PE_FIRSTACCESS;
    }

    my $res = $req->data->{enabledMods0}->[0]->extractFormInfo($req);
    if ( $res > 0 ) {
        $self->setSecurity($req);
        delete $req->pdata->{_choice};
    }
    return $res;
}

sub authenticate {
    my $res = $_[1]->data->{enabledMods0}->[0]->authenticate( $_[1] );
    delete $_[1]->pdata->{_choice} if ( $res > 0 );
    return $res;
}

sub setAuthSessionInfo {
    my ( $self, $req ) = @_;
    $self->checkChoice($req) unless ( $req->data->{enabledMods0} );
    my $res = $req->data->{enabledMods0}->[0]->setAuthSessionInfo($req);
    delete $_[1]->pdata->{_choice} if ( $res > 0 );
    return $res;
}

sub authLogout {
    $_[0]->checkChoice( $_[1] ) or return PE_OK;
    my $res = $_[1]->data->{enabledMods0}->[0]->authLogout( $_[1] );
    delete $_[1]->pdata->{_choice};
    delete $_[1]->data->{_authChoice};
    return $res;
}

sub setSecurity {
    my ( $self, $req ) = @_;
    foreach my $mod ( values %{ $self->modules } ) {
        if ( $mod->can('setSecurity') ) {
            $mod->setSecurity($req);
            last;
        }
    }
}

1;
