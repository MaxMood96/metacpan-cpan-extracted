package CXC::Gnuplot::V1::MultiPlot::Title;

use v5.38;
use experimental 'builtin';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::MultiPlot::Title : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use CXC::Gnuplot::V1::Types -lexical => qw(
  Enum is_Str
);
use CXC::Gnuplot::V1::Util
  -lexical => 'maybe_quote',
  'pvalidate', 'to_hash_r', 'render_opts';

no namespace::clean;

use Ref::Util qw( is_ref );

use namespace::clean;

use builtin 'is_bool';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $text       :param  :reader;
field $font       :param  :reader  = undef;
field $enhanced   :param  :reader  = undef;
field $justify    :param  :reader  = undef;
field $textcolor  :param  :reader  = undef;
#>>>




















ADJUST {

    pvalidate( font => Font => \$font );

    pvalidate( textcolor => ColorSpec => \$textcolor );

    # {{no}enhanced}
    # $enhanced => Bool
    defined $enhanced
      and !is_bool( $enhanced )
      and croak( q{invalid value for "enhanced" parameter; must be bool} );

    # $justify => [ left, center, right ]
    pvalidate( justify => Enum->of( 'left', 'right', 'center' ), \$justify );
}















method BUILDARGS : common (@args ) {
    return ( text => $args[0] ) if @args == 1 && !is_ref( $args[0] );
    return $class->SUPER::BUILDARGS( @args );
}







method to_hash {

    to_hash_r( {
        ( defined $text      ? ( text      => $text )      : () ),
        ( defined $font      ? ( font      => $font )      : () ),
        ( defined $enhanced  ? ( enhanced  => $enhanced )  : () ),
        ( defined $textcolor ? ( textcolor => $textcolor ) : () ),
        ( defined $justify   ? ( justify   => $justify )   : () ),
    } );

}





method opts {

    my @opts;

    push @opts, maybe_quote( $text );

    push @opts, render_opts( font => $font );

    defined $enhanced
      and push @opts, $enhanced ? 'enhanced' : 'noenhaced';

    defined $justify
      and push @opts, $justify;

    push @opts, render_opts( textcolor => $textcolor );

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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory autotitle textcolor

=head1 NAME

CXC::Gnuplot::V1::MultiPlot::Title

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 text

=head2 enhanced

=head2 justify

=head2 font

=head2 textcolor

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash
reference. As shorthand, a single scalar is used as the C<text> parameter:

  $object = $class->new( $text )

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
