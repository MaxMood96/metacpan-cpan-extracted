package CXC::Gnuplot::V0::CoordPosition2D;

use v5.38;
use experimental 'declared_refs';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::CoordPosition2D;

use CXC::Gnuplot::V0::Types -lexical => 'CoordValue';

use CXC::Gnuplot::V0::Util
  -lexical => 'pvalidate',
  'to_hash_r';

#<<< no tidy
field $x  :param  :reader;
field $y  :param  :reader;
#>>>














ADJUST {
    pvalidate( x => CoordValue, \$x );
    pvalidate( y => CoordValue, \$y );
}





method to_hash ( %args ) {
    to_hash_r( {
        ( defined $x ? ( x => $x ) : () ),    #
        ( defined $y ? ( y => $y ) : () ),
    } );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}





method opts {
    return join( q{,}, $x, $y );
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

CXC::Gnuplot::V0::CoordPosition2D

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 x

=head2 y

=head1 CLASS METHODS

=head2 new

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
