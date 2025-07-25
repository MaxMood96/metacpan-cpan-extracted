package Moose::Meta::Method::Accessor::Native::Hash::exists;
our $VERSION = '2.4000';

use strict;
use warnings;

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Reader',
     'Moose::Meta::Method::Accessor::Native::Hash';

sub _minimum_arguments { 1 }

sub _maximum_arguments { 1 }

sub _inline_check_arguments {
    my $self = shift;

    return $self->_inline_check_var_is_valid_key('$_[0]');
}

sub _return_value {
    my $self = shift;
    my ($slot_access) = shift;

    return 'exists ' . $slot_access . '->{ $_[0] }';
}

no Moose::Role;

1;
