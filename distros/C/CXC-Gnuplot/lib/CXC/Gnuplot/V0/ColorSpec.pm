package CXC::Gnuplot::V0::ColorSpec;

use v5.38;
use experimental 'declared_refs';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::ColorSpec;

no namespace::clean;

use Ref::Util 'is_ref', 'is_plain_hashref';

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical, 'is_PositiveOrZeroInt', 'is_RGBColor', 'Palette';

use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'pvalidate',
  'clone_object', 'gnuplot_color', 'to_hash_r', 'quote';

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





method to_hash ( %args ) {
    return to_hash_r( {
        ( defined $rgbcolor ? ( rgbcolor => $rgbcolor ) : () ),    #
        ( defined $palette  ? ( palette  => $palette )  : () ),
    } );
}





sub coerce_attrs ( $class, @attrs ) {
    return @attrs == 1 && !is_ref( $attrs[0] )
      ? { rgbcolor => $attrs[0] }
      : undef;
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
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

CXC::Gnuplot::V0::ColorSpec

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 rgbcolor

=head2 palette

=head1 CLASS METHODS

=head2 new

=head2 coerce_attrs

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 opts

=head1 INTERNALS

=for Pod::Coverage META
DOES

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
