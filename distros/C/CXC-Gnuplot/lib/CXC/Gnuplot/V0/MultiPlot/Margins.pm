package CXC::Gnuplot::V0::MultiPlot::Margins;

use v5.38;
use Feature::Compat::Class;
use experimental 'builtin';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::MultiPlot::Margins;

use builtin 'is_bool', 'false';

use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'clone_object', 'pvalidate', 'to_hash_r';
use CXC::Gnuplot::V0::Types -lexical => qw( Num );

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $top     :param  :reader  = undef;
field $bottom  :param  :reader  = undef;
field $left    :param  :reader  = undef;
field $right   :param  :reader  = undef;
#>>>

















ADJUST {

    croak( 'all margins must be specified' )
      unless defined $top
      and defined $bottom
      and defined $left
      and defined $right;

    pvalidate( top    => Num, \$top );
    pvalidate( bottom => Num, \$bottom );
    pvalidate( left   => Num, \$left );
    pvalidate( right  => Num, \$right );
}






method to_hash {

    to_hash_r( {
        ( defined $top    ? ( top    => $top )    : () ),
        ( defined $bottom ? ( bottom => $bottom ) : () ),
        ( defined $left   ? ( left   => $left )   : () ),
        ( defined $right  ? ( right  => $right )  : () ),
    } );

}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    clone_object( $self, \%args );
}






method opts {
    # only use as many margins as specified.
    # to specify a specific margin, use the [lrtb]margin commands
    ## no critic (NamingConventions::ProhibitAmbiguousNames)
    my @margins = ( $left, $right, $bottom, $top );
    pop @margins while @margins && !defined $margins[-1];

    return ( @margins ? join( q{,}, @margins ) : () );
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

CXC::Gnuplot::V0::MultiPlot::Margins

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 top

=head2 bottom

=head2 left

=head2 right

=head1 CLASS METHODS

=head2 new

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
