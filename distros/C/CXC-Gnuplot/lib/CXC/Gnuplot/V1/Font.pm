package CXC::Gnuplot::V1::Font;

use v5.38;
use experimental 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Font : isa(CXC::Gnuplot::V1::Base) does( CXC::Gnuplot::V1::Role::Clone );

use CXC::Gnuplot::V1::Types -lexical, 'is_PositiveInt';
use CXC::Gnuplot::V1::Util -lexical => 'to_hash_r', 'quote';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $name  :param  :reader = undef;
field $size  :param  :reader = undef;
#>>>














ADJUST {

    defined $name
      and !length $name
      and croak( '"name" must be non-empty' );

    defined $size
      and !is_PositiveInt( $size )
      and croak( '"size" must be a positive integer' );

}



















method to_hash ( %args ) {
    to_hash_r( {
        ( defined $name ? ( name => $name ) : () ),    #
        ( defined $size ? ( size => $size ) : () ),
    } );
}






method opts {
    my $font = join( q{,}, $name // q{}, $size // () );
    return ( length( $font ) ? quote( $font ) : () );
}




1;

#
# This file is part of CXC-Gnuplot
#
# This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

CXC::Gnuplot::V1::Font

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 name

=head2 size

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash reference.

=head1 METHODS

=head2 to_hash

Returns a hashref whose contents can be passed to the constructor to
generate a duplicate of the object.

=head2 opts

=head1 INTERNALS

=for Pod::Coverage META
DOES
BUILDARGS
clone

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-cxc-gnuplot@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=CXC-Gnuplot>

=head2 Source

Source is available at

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot

and may be cloned from

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<CXC::Gnuplot|CXC::Gnuplot>

=back

=head1 AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
