package Moose::Exception::RolesDoNotSupportInner;
our $VERSION = '2.4000';

use Moose;
extends 'Moose::Exception';

sub _build_message {
    "Roles cannot support 'inner'";
}

__PACKAGE__->meta->make_immutable;
1;
