package CXC::Gnuplot::V1::Terminal::cairo;

use v5.38;
use Object::Pad 0.821;
use experimentals 'builtin';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Terminal::cairo : isa(CXC::Gnuplot::V1::TerminalBase);

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

use CXC::Gnuplot::V1::Types -lexical, qw( PositiveNum Enum );
use CXC::Gnuplot::V1::Util -lexical => 'pvalidate', 'to_hash_r';

use builtin 'is_bool';

#<<< no tidy
field $enhanced     :param  :reader  = undef;
field $color        :param  :reader  = undef;
field $background   :param  :reader  = undef;
field $font         :param  :reader  = undef;
field $fontscale    :param  :reader  = undef;
field $linewidth    :param  :reader  = undef;
field $linejoin     :param  :reader  = undef;
field $dashlength   :param  :reader  = undef;
#>>>
































ADJUST {

    if ( __CLASS__ eq __PACKAGE__ ) {
        require Carp;
        Carp::croak( "can't instantiate @{[__CLASS__]}" );
    }

    defined $enhanced
      and !is_bool( $enhanced )
      and croak( q{invalid value for "enhanced" parameter: must be bool} );

    defined $color
      and !is_bool( $color )
      and croak q{invalid value for "color" parameter: must be bool};

    pvalidate( font => Font => \$font );

    pvalidate( fontscale  => PositiveNum,                             \$fontscale );
    pvalidate( linewidth  => PositiveNum,                             \$linewidth );
    pvalidate( linejoin   => Enum->of( 'rounded', 'butt', 'square' ), \$linejoin );
    pvalidate( dashlength => PositiveNum,                             \$dashlength );
}








method to_hash {

    to_hash_r( {
        $self->SUPER::to_hash->%*,
        ( defined $enhanced   ? ( enhanced   => $enhanced )   : () ),
        ( defined $color      ? ( color      => $color )      : () ),
        ( defined $fontscale  ? ( fontscale  => $fontscale )  : () ),
        ( defined $linewidth  ? ( linewidth  => $linewidth )  : () ),
        ( defined $linejoin   ? ( linejoin   => $linejoin )   : () ),
        ( defined $dashlength ? ( dashlength => $dashlength ) : () ),
        ( defined $font       ? ( font       => $font )       : () ),
    } );

}





method opts {

    return (
        $self->SUPER::opts,
        ( defined $enhanced   ? $enhanced ? 'enhanced' : 'noenhanced' : () ),
        ( defined $color      ? $color    ? 'color'    : 'mono'       : () ),
        ( defined $background ? [ background => $background ] : () ),
        ( defined $fontscale  ? [ fontscale => $fontscale ]   : () ),
        ( defined $linewidth  ? [ linewidth => $linewidth ]   : () ),
        ( defined $linejoin   ? $linejoin                     : () ),
        ( defined $dashlength ? [ dashlength => $dashlength ] : () ),
    );
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory dashlength fontscale
linejoin linewidth

=head1 NAME

CXC::Gnuplot::V1::Terminal::cairo

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 enhanced

=head2 color

=head2 background

=head2 font

=head2 fontscale

=head2 linewidth

=head2 linejoin

=head2 dashlength

=head1 CONSTRUCTORS

=head2 new

=head1 METHODS

=head2 to_hash

Returns a hashref whose contents can be passed to the constructor to
generate a duplicate of the object.

=head2 opts

=head1 SUBROUTINES

=head2 terminal

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
