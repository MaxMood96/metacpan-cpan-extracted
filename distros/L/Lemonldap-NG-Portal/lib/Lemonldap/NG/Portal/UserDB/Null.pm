package Lemonldap::NG::Portal::UserDB::Null;

use strict;
use Mouse;
use Lemonldap::NG::Portal::Main::Constants;

extends 'Lemonldap::NG::Portal::Main::UserDB';

our $VERSION = '2.19.0';

# INITIALIZATION

sub init {
    return 1;
}

# RUNNING METHODS

sub getUser {
    return PE_OK;
}

sub findUser {
    return PE_OK;
}

sub setSessionInfo {
    return PE_OK;
}

sub setGroups {
    return PE_OK;
}

1;
