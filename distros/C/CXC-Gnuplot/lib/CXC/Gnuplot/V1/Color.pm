package CXC::Gnuplot::V1::Color;

use v5.38;
use experimental 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Color : isa(CXC::Gnuplot::V1::Base) does( CXC::Gnuplot::V1::Role::Clone );

use CXC::Gnuplot::V1::Util -lexical, 'to_hash_r';

## no critic (Community::DollarAB)
#<<< no tidy
field $name  :param  :reader;
field $rgb   :param  :reader;
field $r     :param  :reader;
field $g     :param  :reader;
field $b     :param  :reader;
#>>>





























method to_hash ( ) {
    to_hash_r( {
        ( defined $name ? ( name => $name ) : () ),
        ( defined $rgb  ? ( rgb  => $rgb )  : () ),
        ( defined $r    ? ( r    => $r )    : () ),
        ( defined $g    ? ( g    => $g )    : () ),
        ( defined $b    ? ( b    => $b )    : () ),
    } );
}

#
# This file is part of CXC-Gnuplot
#
# This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

1;

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory rgb

=head1 NAME

CXC::Gnuplot::V1::Color

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 name

=head2 rgb

=head2 r

=head2 g

=head2 b

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash reference.

=head1 METHODS

=head2 to_hash

Returns a hashref whose contents can be passed to the constructor to
generate a duplicate of the object.

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
