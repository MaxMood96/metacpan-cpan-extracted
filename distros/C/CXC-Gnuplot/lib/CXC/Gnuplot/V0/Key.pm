package CXC::Gnuplot::V0::Key;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::Key;

use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'clone_object', 'pvalidate', 'to_hash_r', 'render_opts', 'render_set';

use CXC::Gnuplot::V0::Types -lexical => qw(
  ArrayRef
  CoordPosition2D
  Enum
  NonEmptyStr
  Num
  PositiveInt
  PositiveNum
  PositiveOrZeroNum
  SetFormats
  Str
  Tuple
  is_NonEmptyStr
  is_PositiveInt
  is_PositiveNum

  signature_for
);

use builtin 'true', 'is_bool';

no namespace::clean;

use Ref::Util 'is_plain_arrayref';

use namespace::clean;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $on                :param  :reader  = undef;
field $default           :param  :reader  = true;
field $font              :param  :reader  = undef;
field $enhanced          :param  :reader  = undef;
field $title             :param  :reader  = undef;
field $autotitle         :param  :reader  = undef;
field $box               :param  :reader  = undef;
field $opaque            :param  :reader  = undef;
field $width             :param  :reader  = undef;
field $height            :param  :reader  = undef;

field $region            :param  :reader  = undef;
field $margin            :param  :reader  = undef;
field $horiz             :param  :reader  = undef;
field $vert              :param  :reader  = undef;
field $at                :param  :reader  = undef;
field $offset            :param  :reader  = undef;

field $layout            :param  :reader  = undef;
field $maxcols           :param  :reader  = undef;
field $maxrows           :param  :reader  = undef;
field $columns           :param  :reader  = undef;
field $keywidth          :param  :reader  = undef;
field $justifyentrytext  :param  :reader  = undef;

field $reverse           :param  :reader  = undef;
field $invert            :param  :reader  = undef;
field $samplen           :param  :reader  = undef;
field $spacing           :param  :reader  = undef;
field $textcolor         :param  :reader  = undef;
#>>>































































ADJUST {

    my $e;

    # this is equivalent to 'set/unset key'
    # {on|off}
    # $on => Bool
    defined $on
      and !is_bool( $on )
      and croak q{invalid value for "on" parameter: must be bool};

    # {default}
    # $default => Bool
    defined $default
      and !is_bool( $default )
      and croak q{invalid value for "default" parameter: must be bool};

    #------------------------------------------------------
    # general font parameters, which affect all of the entries
    # in the key.

    # {font "<face>,<size>"}
    # $font => Font|ArrayRef
    pvalidate( font => Font => \$font );

    # {{no}enhanced}
    # $enhanced => Bool
    defined $enhanced
      and !is_bool( $enhanced )
      and croak( q{invalid value for "enhanced" parameter; must be bool} );

    pvalidate( title => 'Key::Title' => \$title );

    # we can accept traditional bools here, as the only possible
    # values are boolean or 'columnheader'
    # {{no}autotitle {columnheader}}
    defined $autotitle
      and !is_bool( $autotitle )
      and $autotitle ne 'columnheader'
      and croak( q{invalid value for "autotitle" parameter} );

    # this doesn't validate the line properties
    # {{no}box {<line properties>}}
    # box => Bool | ArrayRef[Str]
    defined $box
      and !is_bool( $box )
      and defined( $e = ArrayRef->of( Str )->validate( $box ) )
      and croak( q{invalid value for "box" parameter: must be bool or ArrayRef} );

    # {{no}opaque {fc <colorspec>}}
    # * not future proof; this hardwires 'fc'
    # * doesn't validate that 'fc' is always follwed by a colorspec.
    defined $opaque
      and !is_bool( $opaque )
      and
      defined( $e = Tuple->of( Enum->of( 'fc' ), ArrayRef->of( NonEmptyStr ) )->validate( $opaque ) )
      and croak( q{invalid value for "opaque" parameter: must be bool or [ fc => <colorspec]} );

    # {width <width_increment>}
    defined $width
      and defined( $e = Num->validate( $width ) )
      and croak( qq{invalid value for "width" parameter: $e} );

    # {height <height_increment>}
    pvalidate( height => Num, \$height );

    pvalidate( region => Enum->of( 'inside', 'outside', 'fixed' ), \$region );

    pvalidate( margin => Enum->of( 'left', 'right', 'top', 'bottom' ), \$margin );

    pvalidate( horiz => Enum->of( 'left', 'right', 'center' ), \$horiz );

    pvalidate( vert => Enum->of( 'top', 'bottom', 'center' ), \$vert );

    pvalidate( at => CoordPosition2D, \$at );

    pvalidate( offset => CoordOffset2D => \$offset );

    pvalidate( layout => Enum [ 'vertical', 'horizontal' ], \$layout );

    pvalidate( maxcols => PositiveInt | Enum ['auto'], \$maxcols );

    pvalidate( maxrows => PositiveInt | Enum ['auto'], \$maxrows );

    pvalidate( columns => PositiveInt, \$columns );

    pvalidate(
        keywidth => Tuple->of( Enum [ 'screen', 'graph' ], PositiveNum ) | PositiveNum,
        \$keywidth,
    );

    pvalidate( justifyentrytext => Enum->of( 'left', 'right' ), \$justifyentrytext );

    defined $reverse
      and !is_bool( $reverse )
      and croak q{invalid value for "reverse" parameter};

    defined $invert
      and !is_bool( $invert )
      and croak q{invalid value for "invert" parameter};

    pvalidate( samplen => PositiveOrZeroNum, \$samplen );

    pvalidate( spacing => PositiveNum, \$spacing );

    pvalidate( textcolor => ColorSpec => \$textcolor );
}






method to_hash {

    my %hash = (
        ( defined $default          ? ( default          => $default )          : () ),
        ( defined $font             ? ( font             => $font )             : () ),
        ( defined $enhanced         ? ( enhanced         => $enhanced )         : () ),
        ( defined $title            ? ( title            => $title )            : () ),
        ( defined $autotitle        ? ( autotitle        => $autotitle )        : () ),
        ( defined $box              ? ( box              => $box )              : () ),
        ( defined $opaque           ? ( opaque           => $opaque )           : () ),
        ( defined $width            ? ( width            => $width )            : () ),
        ( defined $height           ? ( height           => $height )           : () ),
        ( defined $region           ? ( region           => $region )           : () ),
        ( defined $margin           ? ( margin           => $margin )           : () ),
        ( defined $horiz            ? ( horiz            => $horiz )            : () ),
        ( defined $vert             ? ( vert             => $vert )             : () ),
        ( defined $at               ? ( at               => $at )               : () ),
        ( defined $offset           ? ( offset           => $offset )           : () ),
        ( defined $layout           ? ( layout           => $layout )           : () ),
        ( defined $maxcols          ? ( maxcols          => $maxcols )          : () ),
        ( defined $maxrows          ? ( maxrows          => $maxrows )          : () ),
        ( defined $columns          ? ( columns          => $columns )          : () ),
        ( defined $keywidth         ? ( keywidth         => $keywidth )         : () ),
        ( defined $justifyentrytext ? ( justifyentrytext => $justifyentrytext ) : () ),
        ( defined $reverse          ? ( reverse          => $reverse )          : () ),
        ( defined $invert           ? ( invert           => $invert )           : () ),
        ( defined $samplen          ? ( samplen          => $samplen )          : () ),
        ( defined $spacing          ? ( spacing          => $spacing )          : () ),
        ( defined $textcolor        ? ( textcolor        => $textcolor )        : () ),
    );

    return to_hash_r( \%hash );
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    clone_object( $self, \%args );
}






method opts {

    state %MapMargin = (
        left   => 'lmargin',
        right  => 'rmargin',
        top    => 'tmargin',
        bottom => 'bmargin',
    );

    state %MapEntryJustify = (
        left  => 'Left',
        right => 'Right',
    );

    defined $on
      and !$on
      and return 'off';

    my @opts;

    defined $on
      and $on
      and push @opts, 'on';

    defined $default
      and $default
      and push @opts, 'default';

    push @opts, render_opts( font => $font );

    defined $enhanced
      and push @opts, $enhanced ? 'enhanced' : 'noenhaced';

    defined $title
      and push @opts, is_bool( $title ) && !$title
      ? 'notitle'
      : render_opts( title => $title );

    push @opts, render_opts( textcolor => $textcolor );

    push @opts,
        $autotitle eq 'columnheader' ? [ autotitle => 'columnheader' ]
      : $autotitle                   ? 'autotitle'
      : 'noautotitle'
      if defined $autotitle;

    push @opts,
        !$box                     ? 'nobox'
      : is_plain_arrayref( $box ) ? [ box => $box->@* ]
      : 'box'
      if defined $box;

    push @opts, !$opaque
      ? 'noopaque'
      : [ opaque => $opaque ]
      if defined $opaque;

    push @opts, [ width => $width ]
      if defined $width;

    push @opts, [ height => $height ]
      if defined $height;

    push @opts, $region
      if defined $region;

    push @opts, $MapMargin{$margin}
      if defined $margin;

    push @opts, $horiz
      if defined $horiz;

    push @opts, $vert
      if defined $vert;

    push @opts, render_opts( at     => $at );
    push @opts, render_opts( offset => $offset );

    push @opts, $layout
      if defined $layout;

    push @opts, [ maxcols => $maxcols ]
      if defined $maxcols;

    push @opts, [ maxrows => $maxrows ]
      if defined $maxrows;

    push @opts, [ columns => $columns ]
      if defined $columns;

    push @opts, [ keywidth => $keywidth ]
      if defined $keywidth;

    push @opts, $MapEntryJustify{$justifyentrytext}
      if defined $justifyentrytext;

    push @opts, $reverse ? 'reverse' : 'noreverse'
      if defined $reverse;

    push @opts, $invert ? 'invert' : 'noinvert'
      if defined $invert;

    push @opts, [ samplen => $samplen ]
      if defined $samplen;

    push @opts, [ spacing => $spacing ]
      if defined $spacing;

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
    return render_set( [ render_opts( [ set => 'key' ], $self ) ], $opt->as );
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory autotitle horiz
justifyentrytext keywidth maxcols maxrows samplen textcolor

=head1 NAME

CXC::Gnuplot::V0::Key

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 on

=head2 default

=head2 font

=head2 enhanced

=head2 title

=head2 autotitle

=head2 box

=head2 opaque

=head2 width

=head2 height

=head2 region

=head2 margin

=head2 horiz

=head2 vert

=head2 at

=head2 offset

=head2 layout

=head2 maxcols

=head2 maxrows

=head2 columns

=head2 keywidth

=head2 justifyentrytext

=head2 reverse

=head2 invert

=head2 samplen

=head2 spacing

=head2 textcolor

=head1 CLASS METHODS

=head2 new

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 opts

=head2 set

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
