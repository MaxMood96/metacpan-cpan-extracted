package CXC::Gnuplot::V0::AxisFormat;

use v5.38;
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::AxisFormat;

no namespace::clean;

use Ref::Util qw( is_ref );

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical => qw( FormatCoordSys NonEmptyStr);
use CXC::Gnuplot::V0::Util
  -lexical => 'clone_object',
  'assert_coerce_object', 'pvalidate';

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





method to_hash {
    return {
        ( defined $coord  ? ( coord  => $coord )         : () ),    #
        ( defined $format ? ( format => $format->value ) : () ),
    };
}






method clone ( %args ) {
    clone_object( $self, \%args );
}






sub coerce_attrs ( $class, @attrs ) {
    return @attrs == 1 && !is_ref( $attrs[0] )
      ? { format => $attrs[0] }
      : undef;
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
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

CXC::Gnuplot::V0::AxisFormat

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 format

=head2 coord

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
