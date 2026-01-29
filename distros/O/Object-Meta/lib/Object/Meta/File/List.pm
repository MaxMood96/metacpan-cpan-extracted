#
# @author Bodo (Hugo) Barwich
# @version 2026-01-29
# @package Object::Meta
# @subpackage lib/Object/Meta/File/List.pm

# This Module defines Classes to manage Data in an indexed List
#
#---------------------------------
# Requirements:
#
#---------------------------------
# Features:
#

#==============================================================================
# The Object::Meta::File::List Package

=head1 NAME

Object::Meta::File::List - Library to index C<Object::Meta::File> instances by
their C<name> field.

=cut

package Object::Meta::File::List;

#----------------------------------------------------------------------------
#Dependencies

use parent 'Object::Meta::Named::List';

use Scalar::Util 'blessed';

=head1 DESCRIPTION

C<Object::Meta::File::List> implements a class which indexes C<Object::Meta::File>
instances by their C<name> field. It works exactly like the C<Object::Meta::Named::List>
class.

Additionally a C<hash> meta data field will be created for indexation and lookup.

The C<hash> meta data field is used to lookup entries.

=cut

#----------------------------------------------------------------------------
#Constructors

#----------------------------------------------------------------------------
#Administration Methods

=head1 METHODS

=head2 Administration Methods

=head3 Add ( [ C<Object::Meta::File> | DATA ] )

This works like C<Object::Meta::List::Add()> only that it handles
C<Object::Meta::File> instances.

If no parameter is given it creates an empty instance of C<Object::Meta::File>
and adds it to the list

B<Parameters:>

=over 4

=item C<Object::Meta::File>

An instance of C<Object::Meta::File> to be added to the list.

=item C<DATA>

A hash with data to create an instance of C<Object::Meta::File> and add it to the list.

=back

B<Returns:> C<Object::Meta::File> - The object which was created or added.

See L<Method C<Object::Meta::Named::List::Add()>|Object::Meta::Named::List/"Add ( [ C<Object::Meta::Named> | DATA ] )">

See L<Method C<Object::Meta::List::Add()>|Object::Meta::List/"Add ( [ C<Object::Meta> | DATA ] )">

=cut

sub Add {
    my $self   = shift;
    my $mtaety = undef;

    if ( scalar(@_) > 0 ) {
        if ( defined blessed $_[0] ) {
            $mtaety = $_[0];
        }
        else    #Parameter is not an Object
        {
            # Create the new Object::Meta::File object from the given parameters
            $mtaety = Object::Meta::File->new(@_);
        }
    }

    if ( defined $mtaety && !$mtaety->isa('Object::Meta::File') ) {
        $mtaety = undef;
    }

    $mtaety = Object::Meta::File->new unless ( defined $mtaety );

    #Execute the Base Logic
    $self->SUPER::Add($mtaety);

    return $mtaety;
}

return 1;
