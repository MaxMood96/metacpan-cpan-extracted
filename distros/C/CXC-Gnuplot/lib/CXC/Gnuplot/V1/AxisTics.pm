package CXC::Gnuplot::V1::AxisTics;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::AxisTics : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use builtin 'is_bool', 'true', 'false';

no namespace::clean;

use Ref::Util 'is_plain_hashref', 'is_plain_arrayref', 'is_ref';
use List::Util 'none';

use namespace::clean;

use CXC::Gnuplot::V1::Types -lexical, qw(
  Enum
  is_Num
  is_NonEmptyStr
  PerlBoolFalse
  TicList
  TicSeries
  CoordOffset3D
);
use CXC::Gnuplot::V1::Util -lexical, 'maybe_quote', 'pvalidate', 'to_hash_r', 'render_opts';
use CXC::Gnuplot::V1::AxisFormat;


my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $where         :param  :reader  = undef;  # {axis | border}
field $mirror        :param  :reader  = undef;  # {{no}mirror}
field $direction     :param  :reader  = undef;  # {in |out}
field $scale         :param  :reader  = undef;  # {scale {default | <major> {,<minor>}}}
field $rotate        :param  :reader  = undef;  # {{no}rotate {by <ang>}}
field $offset        :param  :reader  = undef;  # {offset <offset> | nooffset}
field $justify       :param  :reader  = undef;  # {left | right | center | autojustify}
field $positions     :param  :reader  = undef;  # {  autofreq
                                                #    | <incr>
                                                #    | <start>, <incr> {,<end>}
                                                #    | ({"<label>"} <pos> {<level>} {,{"<label>"}...) }
field $format        :param  :reader  = undef;
field $font          :param  :reader  = undef;  # {"name{,<size>}"}
field $enhanced      :param  :reader  = undef;  # {{no}enhanced}
field $logscale      :param  :reader  = undef;  #{{no}logscale}
field $rangelimited  :param  :reader  = undef;  # {rangelimited}
field $textcolor     :param  :reader  = undef;  # {colorspec}
#>>>






































ADJUST {

    pvalidate( where => Enum->of( 'axis', 'border' ), \$where );

    defined $mirror
      and !is_bool( $mirror )
      and croak( q{invalid value for "mirror" parameter: must be bool} );

    pvalidate( direction => Enum->of( 'axis', 'border' ), \$direction );

    # for now, just store this as a string
    defined $scale
      and !is_NonEmptyStr( $scale )
      and croak( q{"scale" must be non-empty} );

    defined $rotate
      and !is_bool( $rotate )
      and !is_Num( $rotate )
      and croak( '"rotate" must be a float or a boolean' );

    # offset is either a false boolean or an expression
    pvalidate( offset => PerlBoolFalse | CoordOffset3D, \$offset );

    pvalidate( justify => Enum->of( 'left', 'right', 'center', 'autojustify' ), \$justify );

    pvalidate( positions => Enum->of( 'autofreq' ) | TicSeries | TicList, \$positions );

    pvalidate( format => AxisFormat => \$format );
    pvalidate( font   => Font       => \$font );

    defined $enhanced
      and !is_bool( $enhanced )
      and croak( q{invalid value for "enhanced" parameter: must be bool} );

    defined $logscale
      and !is_bool( $enhanced )
      and croak( q{invalid value for "logscale" parameter: must be bool} );

    defined $rangelimited
      and !is_bool( $rangelimited )
      and croak( q{invalid value for "rangelimited" parameter: must be bool} );

    pvalidate( textcolor => ColorSpec => \$textcolor );
}




















method to_hash {

    to_hash_r( {
        ( defined $where        ? ( where        => $where )        : () ),
        ( defined $mirror       ? ( mirror       => $mirror )       : () ),
        ( defined $direction    ? ( direction    => $direction )    : () ),
        ( defined $scale        ? ( scale        => $scale )        : () ),
        ( defined $rotate       ? ( rotate       => $rotate )       : () ),
        ( defined $offset       ? ( offset       => $offset )       : () ),
        ( defined $justify      ? ( justify      => $justify )      : () ),
        ( defined $positions    ? ( positions    => $positions )    : () ),
        ( defined $enhanced     ? ( enhanced     => $enhanced )     : () ),
        ( defined $logscale     ? ( logscale     => $logscale )     : () ),
        ( defined $rangelimited ? ( rangelimited => $rangelimited ) : () ),
        ( defined $textcolor    ? ( textcolor    => $textcolor )    : () ),
        ( defined $format       ? ( format       => $format )       : () ),
        ( defined $font         ? ( font         => $font )         : () ),
    } );
}

my sub opts_tic_series( $series ) {

    my \%series = $series;
    my @position;

    push @position, $series{start}
      if defined $series{start};

    if ( defined( my $incr = $series{incr} ) ) {
        push @position,
          is_plain_hashref( $incr )
          ? join( q{ }, grep defined, $incr->@{ 'multiple', 'unit' } )
          : $incr;
    }

    push @position, $series{end}
      if defined $series{end};

    return join( ', ', @position );
}

my sub opts_tic_entry ( $entry ) {

    my \%entry = $entry;

    my @pos;

    defined $entry{label}
      and push @pos, maybe_quote( $entry{label} );

    push @pos, $entry{pos};

    defined $entry{level}
      and push @pos, $entry{level};

    return join q{ }, @pos;
}

my sub opts_positions ( $positions ) {

    return () if !defined $positions;

    # start, incr, end
    return opts_tic_series( $positions )
      if is_plain_hashref( $positions );

    # autofreq
    return $positions if !is_plain_arrayref( $positions );

    my \@positions = $positions;

    # add
    my @add  = is_ref( $positions[0] ) ? () : shift @positions;
    my $tics = join q{, }, map { opts_tic_entry( $_ ) } @positions;
    return join q{ }, @add, "( $tics )";
}





method opts {
    my @opts;

    defined $where
      and push @opts, $where;

    defined $mirror
      and push @opts, $mirror ? 'mirror' : 'nomirror';

    defined $direction
      and push @opts, $direction;

    defined $scale
      and push @opts, [ scale => $scale ];

    defined $rotate
      and push @opts, is_bool( $rotate )
      ? ( $rotate ? 'rotate' : 'norotate' )
      : [ 'rotate by' => $rotate ];

    if ( defined $offset ) {
        if ( is_bool( $offset ) ) {
            push @opts, ( $offset ? 'offset' : 'nooffset' );
        }
        else {
            push @opts, render_opts( offset => $offset );
        }

    }

    defined $justify
      and push @opts, $justify;

    defined $positions
      and push @opts, opts_positions( $positions );

    push @opts, render_opts( format => $format );

    push @opts, render_opts( font => $font );

    defined $enhanced
      and push @opts, ( $enhanced ? 'enhanced' : 'noenhanced' );

    defined $logscale
      and push @opts, ( $logscale ? 'logscale' : 'nologscale' );

    defined $rangelimited
      and push @opts, ( $rangelimited ? 'rangelimited' : () );

    push @opts, render_opts( textcolor => $textcolor );

    return @opts;
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory logscale rangelimited
textcolor

=head1 NAME

CXC::Gnuplot::V1::AxisTics

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 where

=head2 mirror

=head2 direction

=head2 scale

=head2 rotate

=head2 offset

=head2 justify

=head2 positions

=head2 format

=head2 font

=head2 enhanced

=head2 logscale

=head2 rangelimited

=head2 textcolor

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash
reference.

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
