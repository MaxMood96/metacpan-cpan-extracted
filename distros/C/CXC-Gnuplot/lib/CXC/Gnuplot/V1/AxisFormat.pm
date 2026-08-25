package CXC::Gnuplot::V1::AxisFormat;

use v5.38;
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::AxisFormat : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use Lexical::Import qw( aliased CXC::Gnuplot::V1::LiteralDataValue);

use Lexical::Import qw( Ref::Util is_ref );

use CXC::Gnuplot::V1::Types -lexical => qw( FormatCoordSys );
use CXC::Gnuplot::V1::Util -lexical => 'pvalidate', 'to_hash_r';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< notidy
field $format  :param  :reader  = undef;
field $coord   :param  :reader  = undef;
#>>>













ADJUST {
    pvalidate( coord  => FormatCoordSys, \$coord );
    pvalidate( format => LiteralDataValue => \$format );
}














method BUILDARGS : common (@args ) {
    return ( format => $args[0] ) if @args == 1 && !is_ref( $args[0] );
    return $class->SUPER::BUILDARGS( @args );
}








method to_hash {
    to_hash_r( {
        ( defined $coord  ? ( coord  => $coord )  : () ),    #
        ( defined $format ? ( format => $format ) : () ),
    } );
}






method opts {

    my @opts;

    if ( defined $format ) {
        push @opts, $format->stringify;
        push @opts, $coord if defined $coord;
    }

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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory coord

=head1 NAME

CXC::Gnuplot::V1::AxisFormat

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 format

=head2 coord

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash
reference. As shorthand, a single scalar is used as the C<format> parameter:

  $object = $class->new( $format )

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
