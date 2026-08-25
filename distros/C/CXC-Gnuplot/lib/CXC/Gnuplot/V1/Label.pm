package CXC::Gnuplot::V1::Label;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Label : isa(CXC::Gnuplot::V1::Base) does( CXC::Gnuplot::V1::Role::Clone );

no namespace::clean;

use Ref::Util 'is_ref', 'is_plain_arrayref';
use builtin 'is_bool', 'true';

use namespace::clean;

use CXC::Gnuplot::V1::Types -lexical, qw(
  is_NonEmptyStr
  is_Num

  ArrayRef
  CoordPosition3D
  Dict
  Enum
  NonEmptyStr
  Num
  Optional
  PerlBool
  PerlBoolFalse
  PositiveInt
  PositiveNum
  SetFormats

  signature_for
);

use CXC::Gnuplot::V1::Util -lexical, 'maybe_quote',

  'pvalidate', 'to_hash_r', 'render_opts', 'render_set';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

# set label {<tag>} {"<label text>"} {at <position>}
#           {left | center | right}
#           {norotate | rotate {by <degrees>}}
#           {font "<name>{,<size>}"}
#           {noenhanced}
#           {front | back}
#           {textcolor <colorspec>}
#           {point <pointstyle> | nopoint}
#           {offset <offset>}
#           {nobox} {boxed {bs <boxstyle>}}
#           {hypertext}


#<<< notidy
field $tag       :param  :reader  = undef;
field $text      :param  :reader  = undef;
field $at        :param  :reader  = undef;
field $justify   :param  :reader  = undef;
field $rotate    :param  :reader  = undef;
field $font      :param  :reader  = undef;
field $enhanced  :param  :reader  = undef;
field $layer     :param  :reader  = undef;
field $textcolor :param  :reader  = undef;
field $point     :param  :reader  = undef;
field $offset    :param  :reader  = undef;
field $boxed     :param  :reader  = undef;
field $hypertext :param  :reader  = undef;
#>>>



































ADJUST {

    pvalidate( tag => PositiveInt, \$tag );

    pvalidate( text => NonEmptyStr, \$text );

    pvalidate( at => CoordPosition3D, \$at );

    pvalidate( justify => Enum->of( 'left', 'right', 'center' ), \$justify );

    pvalidate( rotate => Num | PerlBool, \$rotate );

    pvalidate( font => Font => \$font );

    pvalidate( enhanced => PerlBool, \$enhanced );

    pvalidate( layer => Enum->of( 'front', 'back' ), \$layer );

    pvalidate( textcolor => ColorSpec => \$textcolor );

    pvalidate(
        point => PerlBoolFalse | Dict [
            line  => Optional [PositiveInt],
            type  => PositiveInt | NonEmptyStr,
            size  => Optional [PositiveNum],
            color => Optional [NonEmptyStr],      # TODO: convert this to a ColorSpec object
        ],
        \$point,
    );

    pvalidate( offset => CoordOffset3D => \$offset );

    pvalidate( boxed => PerlBool | PositiveNum, \$boxed );

    pvalidate( hypertext => PerlBool, \$hypertext );
}















method BUILDARGS : common (  @args ) {
    return ( text => $args[0] ) if @args == 1 && !is_ref( $args[0] );
    return $class->SUPER::BUILDARGS( @args );
}








method to_hash {

    to_hash_r( {
        ( defined $tag       ? ( tag       => $tag )       : () ),
        ( defined $text      ? ( text      => $text )      : () ),
        ( defined $at        ? ( at        => $at )        : () ),
        ( defined $justify   ? ( justify   => $justify )   : () ),
        ( defined $rotate    ? ( rotate    => $rotate )    : () ),
        ( defined $font      ? ( font      => $font )      : () ),
        ( defined $enhanced  ? ( enhanced  => $enhanced )  : () ),
        ( defined $layer     ? ( layer     => $layer )     : () ),
        ( defined $textcolor ? ( textcolor => $textcolor ) : () ),
        ( defined $point     ? ( point     => $point )     : () ),
        ( defined $offset    ? ( offset    => $offset )    : () ),
        ( defined $boxed     ? ( boxed     => $boxed )     : () ),
        ( defined $hypertext ? ( hypertext => $hypertext ) : () ),
    } );

}





my %PointMap = (
    line  => 'lt',
    type  => 'pt',
    size  => 'ps',
    color => 'lc',
);


method opts {
    my @opts;

    defined $tag
      and push @opts, $tag;

    defined $text
      and push @opts, maybe_quote( $text );

    push @opts, render_opts( at => $at );

    defined $justify
      and push @opts, $justify;

    # rotate is either a false boolean or a number
    defined $rotate
      and push @opts, is_bool( $rotate )
      ? ( $rotate ? 'rotate' : 'norotate' )
      : [ 'rotate by' => $rotate ];

    push @opts, render_opts( font => $font );

    defined $enhanced
      and push @opts, ( $enhanced ? 'enhanced' : 'noenhanced' );

    defined $layer
      and push @opts, $layer;

    push @opts, render_opts( textcolor => $textcolor );

    defined $hypertext && $hypertext
      and push @opts, 'hypertext';

    defined $point
      and push @opts, [ point => map { $PointMap{$_} => $point->{$_} } sort keys $point->%* ];

    push @opts, render_opts( offset => $offset );

    defined $boxed
      and push @opts, is_bool( $boxed )
      ? ( $boxed ? 'boxed' : 'noboxed' )
      : ( boxed => boxstyle => $boxed );

    return @opts;
}






signature_for set => (
    method => 1,
    named  => [
        as => SetFormats,
        { default => 'string' },
    ],
);

method set ( $opt ) {
    return render_set( [ render_opts( [ set => 'label' ], $self ) ], $opt->as );
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

CXC::Gnuplot::V1::Label

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 tag

=head2 text

=head2 at

=head2 justify

=head2 rotate

=head2 font

=head2 enhanced

=head2 layer

=head2 textcolor

=head2 point

=head2 offset

=head2 boxed

=head2 hypertext

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

=head2 set

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
