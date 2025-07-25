package Moose::Meta::Method::Accessor::Native::Array::first_index;
our $VERSION = '2.4000';

use strict;
use warnings;

use Params::Util ();

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Reader';

sub _minimum_arguments { 1 }

sub _maximum_arguments { 1 }

sub _inline_check_arguments {
    my $self = shift;

    return (
        'if (!Params::Util::_CODELIKE($_[0])) {',
            $self->_inline_throw_exception( InvalidArgumentToMethod =>
                                            'argument                => $_[0],'.
                                            'method_name             => "first_index",'.
                                            'type_of_argument        => "code reference",'.
                                            'type                    => "CodeRef",',
            ) . ';',
        '}',
    );
}

sub _inline_return_value {
    my $self = shift;
    my ($slot_access) = @_;

    return join '',
        'my @values = @{ (' . $slot_access . ') };',
        'my $f = $_[0];',
        'foreach my $i ( 0 .. $#values ) {',
            'local *_ = \\$values[$i];',
            'return $i if $f->();',
        '}',
        'return -1;';
}

# Not called, but needed to satisfy the Reader role
sub _return_value { }

no Moose::Role;

1;
