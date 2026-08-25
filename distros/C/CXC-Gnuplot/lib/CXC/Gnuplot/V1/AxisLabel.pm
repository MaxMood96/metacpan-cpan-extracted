package CXC::Gnuplot::V1::AxisLabel;

use v5.38;
use experimental 'builtin';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::AxisLabel : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use builtin 'is_bool', 'false';

no namespace::clean;

use Ref::Util 'is_ref';

use namespace::clean;

use CXC::Gnuplot::V1::Types -lexical, 'is_Num', 'is_NonEmptyStr';
use CXC::Gnuplot::V1::Util -lexical, 'maybe_quote', 'pvalidate', 'to_hash_r', 'render_opts';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}


#<<< notidy
field $text       :param  :reader  = undef;
field $offset     :param  :reader  = undef;
field $font       :param  :reader  = undef;
field $textcolor  :param  :reader  = undef;
field $enhanced   :param  :reader  = undef;
field $rotate     :param  :reader  = undef;
#>>>





















ADJUST {

    pvalidate( offset => CoordOffset3D => \$offset );
    pvalidate( font   => Font          => \$font );

    pvalidate( textcolor => ColorSpec => \$textcolor );

    defined $enhanced
      and $enhanced = !!$enhanced;

    defined $rotate
      and $rotate ne 'norotate'
      and $rotate ne 'parallel'
      and !( is_bool( $rotate ) && !$rotate )
      and !is_Num( $rotate )
      and
      croak( '"rotate" must be a float or one of "parallel", "norotate", or the false boolean value' );

}















method BUILDARGS : common (@args ) {
    return ( text => $args[0] ) if @args == 1 && !is_ref( $args[0] );
    return $class->SUPER::BUILDARGS( @args );
}








method to_hash {
    to_hash_r( {
        ( defined $text      ? ( text      => $text )      : () ),
        ( defined $offset    ? ( offset    => $offset )    : () ),
        ( defined $font      ? ( font      => $font )      : () ),
        ( defined $textcolor ? ( textcolor => $textcolor ) : () ),
        ( defined $enhanced  ? ( enhanced  => $enhanced )  : () ),
        ( defined $rotate    ? ( rotate    => $rotate )    : () ),
    } );
}





method opts {
    my @opts;

    defined $text
      and push @opts, maybe_quote( $text );

    push @opts, render_opts( offset => $offset );
    push @opts, render_opts( font   => $font );

    push @opts, render_opts( textcolor => $textcolor );

    defined $enhanced
      and push @opts, ( $enhanced ? 'enhanced' : 'noenhanced' );

    defined $rotate
      and push @opts,
      is_Num( $rotate )       ? [ 'rotate by' => $rotate ]
      : $rotate eq 'parallel' ? [ rotate => 'parallel' ]
      :                         'norotate';

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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory textcolor

=head1 NAME

CXC::Gnuplot::V1::AxisLabel

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 text

=head2 offset

=head2 font

=head2 textcolor

=head2 enhanced

=head2 rotate

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
