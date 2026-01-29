#
# @author Bodo (Hugo) Barwich
# @version 2026-01-29
# @package Object::Meta
# @subpackage lib/Object/Meta/File.pm

# This Module defines Classes to manage Data in an indexed List
#
#---------------------------------
# Requirements:
#
#---------------------------------
# Features:
#

#==============================================================================
# The Object::Meta::File Package

=head1 NAME

Object::Meta::File - Library to recognise a special C<directoryname> field from the raw data

=cut

package Object::Meta::File;

#----------------------------------------------------------------------------
#Dependencies

use parent 'Object::Meta::Named';

=head1 DESCRIPTION

C<Object::Meta::File> implements a class which adds a C<name> and a C<directoryname> field
to the raw data which can be used to index the C<Object::Meta> entries.
It works exactly like the C<Object::Meta::Named> class.

Additionally a C<hash> meta data field will be created for indexation and lookup.

The C<hash> meta data field becomes the index field.

=cut

#----------------------------------------------------------------------------
#Constructors

=head1 METHODS

=head2 Constructor

=head3 new ( [ DATA ] )

This is the constructor for a new C<Object::Meta::File> object.
It creates a new object from B<raw data> which is passed in a hash key / value pairs.

B<Parameters:>

=over 4

=item C<DATA>

The B<raw data> which is passed in a hash key / value pairs.

If a C<name> field is present it will be used to index the entry.

If a C<directoryname> field is present it will be passed to the C<setDirectoryName()>
method.

=back

See L<Method C<Object::Meta::Named::new()>|Object::Meta::Named/"new ( [ DATA ] )">

=cut

sub new {
    my $class = ref( $_[0] ) || $_[0];

    #Take the Method Parameters
    my %hshprms = @_[ 1 .. $#_ ];

    my $self = $class->SUPER::new(%hshprms);

    if ( defined $hshprms{'directoryname'} ) {
        Object::Meta::File::setDirectoryName( $self, $hshprms{'directoryname'} );
    }
    else {
        Object::Meta::File::setDirectoryName $self;
    }

    #Give the Object back
    return $self;
}

#----------------------------------------------------------------------------
#Administration Methods

=head2 Administration Methods

=head3 set ( DATA )

This overrides the base method C<Object::Meta::Named::set()> to recognize the
C<name> and C<directoryname> field.

See L<Method C<Object::Meta::Named::set()>|Object::Meta::Named/"set ( DATA )">

See L<Method C<Object::Meta::set()>|Object::Meta/"set ( DATA )">

=cut

sub set {
    my ( $self, %hshprms ) = @_;

    if ( defined $hshprms{'directoryname'} ) {
        Object::Meta::File::setDirectoryName( $self, delete $hshprms{'directoryname'} );
    }

    Object::Meta::Named::set( $self, %hshprms );
}

=head3 setDirectoryName ( [ DIRECTORY ] )

This will create a C<directoryname> field in the raw data.

B<Parameters:>

=over 4

=item C<DIRECTORY>

The string value for the directory name of the object.

If C<DIRECTORY> is empty or is undefined it will empty the C<directoryname> field.

If C<DIRECTORY> does not have a trailing slash C< / > it will be added.

=back

=cut

sub setDirectoryName {
    my $self = $_[0];

    if ( scalar(@_) > 1 ) {
        Object::Meta::set( $self, 'directoryname', $_[1] );
    }
    else {
        Object::Meta::set( $self, 'directoryname', '' );
    }

    if ( $self->[Object::Meta::LIST_DATA]{'directoryname'} ne '' ) {
        $self->[Object::Meta::LIST_DATA]{'directoryname'} .= '/'
          unless ( $self->[Object::Meta::LIST_DATA]{'directoryname'} =~ m#/$# );

    }
}

#----------------------------------------------------------------------------
#Consultation Methods

=head2 Consultation Methods

=head3 getDirectoryName ()

Returns the content of the C<directoryname> field.

=cut

sub getDirectoryName {
    return $_[0]->[Object::Meta::LIST_DATA]{'directoryname'};
}

return 1;
