package CXC::Gnuplot::V1::ColorSpec;

use v5.38;
use experimental 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::ColorSpec : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

no namespace::clean;

use Ref::Util 'is_ref', 'is_plain_hashref';

use namespace::clean;

use CXC::Gnuplot::V1::Types -lexical, 'is_PositiveOrZeroInt', 'is_RGBColor', 'Palette';

use CXC::Gnuplot::V1::Util
  -lexical => 'pvalidate',
  'gnuplot_color', 'to_hash_r', 'quote';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $rgbcolor  :param  :reader = undef;
field $palette  :param  :reader = undef;
field $_color;
#>>>














ADJUST {

    defined $rgbcolor
      and defined $palette
      and croak( 'specify only one of "rgbcolor" or "palette"' );

    pvalidate( palette => Palette, \$palette );

    # take this time to convert $rgbcolor while it's being validated.
    if ( defined $rgbcolor ) {

        if ( length $rgbcolor ) {

            ## no critic( ControlStructures::ProhibitCascadingIfElse )
            if ( $_color = gnuplot_color( $rgbcolor ) ) {
                $_color = [ rgbcolor => quote( $_color->name ) ];
            }
            elsif ( is_RGBColor( $rgbcolor ) ) {
                $_color = [ rgbcolor => quote( $rgbcolor ) ];
            }
            elsif ( is_PositiveOrZeroInt( $rgbcolor ) || $rgbcolor eq 'variable' ) {
                $_color = [ rgbcolor => $rgbcolor ];
            }
            elsif ( $rgbcolor eq 'bgnd' ) {
                $_color = $rgbcolor;
            }
        }

        defined $_color
          or croak( "unrecognized color: $rgbcolor" );
    }
}














method BUILDARGS : common (@args ) {
    return ( rgbcolor => $args[0] ) if @args == 1 && !is_ref( $args[0] );
    return $class->SUPER::BUILDARGS( @args );
}








method to_hash ( %args ) {
    return to_hash_r( {
        ( defined $rgbcolor ? ( rgbcolor => $rgbcolor ) : () ),    #
        ( defined $palette  ? ( palette  => $palette )  : () ),
    } );
}





method opts {

    my @opts;

    # palette will only ever have one key.
    defined $palette
      and push @opts, [ palette => is_plain_hashref( $palette ) ? [ $palette->%* ] : $palette ];

    defined $_color
      and push @opts, $_color;

    return @opts;
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory rgbcolor

=head1 NAME

CXC::Gnuplot::V1::ColorSpec

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 rgbcolor

=head2 palette

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash
reference. As shorthand, a single scalar is used as the C<rgbcolor> parameter:

  $object = $class->new( $rgbcolor )

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
