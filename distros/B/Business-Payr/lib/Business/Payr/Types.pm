package Business::Payr::Types;

=head1 NAME

Business::Payr::Types - Moose type constraints for Business::Payr

=cut

use strict;
use warnings;

use Moose::Util::TypeConstraints;

# The UserAgent can be a real Mojo::UserAgent or a Test::MockObject
# so we can do "end to end" testing without actually going out on the wire
subtype 'UserAgent'
    => as 'Object'
    => where {
        $_->isa( 'Mojo::UserAgent' )
        or $_->isa( 'Test::MockObject' )
    }
;

1;

# vim: ts=4:sw=4:et
