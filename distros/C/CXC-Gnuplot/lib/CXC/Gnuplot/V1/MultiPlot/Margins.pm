package CXC::Gnuplot::V1::MultiPlot::Margins;

use v5.38;
use Object::Pad 0.821;
use experimental 'builtin';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::MultiPlot::Margins : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use builtin 'is_bool', 'false';

use CXC::Gnuplot::V1::Util
  -lexical => 'pvalidate',
  'to_hash_r';
use CXC::Gnuplot::V1::Types -lexical => qw( Num );

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

CXC::Gnuplot::V1::MultiPlot::Margins

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 top

=head2 bottom

=head2 left

=head2 right

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
