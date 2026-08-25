package CXC::Gnuplot::V0::Types;

use v5.38;
use experimental 'builtin';

our $VERSION = 'v0.29.3';

use Type::Utils -all;
use Type::Library
  -extends => [ 'Types::Standard', 'Types::Common::Numeric', 'Types::Common::String', ],
  -declare => qw(
  ColorSpec
  CoordOffset2D
  CoordOffset3D
  CoordPosition2D
  CoordPosition3D
  CoordSys
  CoordValue
  Coords
  FormatCoordSys
  Fraction
  LiteralDataValue
  MultiPlotLayout
  Palette
  Range
  RGBColor
  SetFormats
  TicEntry
  TicEntries
  AddTicEntries
  TicIncr
  TicList
  TicPosition
  TicSeries
  TicTimeIncr
  TicTimeUnits
  );

use Type::Params 'signature_for';

use Exporter::Shiny qw(
  COORDSYS
  FORMAT_COORD_SYS
  signature_for
);


use Types::Common::Numeric 'is_PositiveInt';

## no critic (CodeLayout::ProhibitQuotedWordLists)
use constant COORDSYS => ( 'first', 'second', 'polar', 'graph', 'screen', 'character', 'char' );
use constant FORMAT_COORD_SYS => ( 'numeric', 'timedate', 'geographic' );

declare CoordSys, as Enum [COORDSYS];

# this is silly. would prefer to truly validate the date, but
# that's difficult without providing a format.
use constant Date => NonEmptyStr;

declare LiteralDataValue, as InstanceOf ['CXC::Gnuplot::V0::LiteralDataValue'];

coerce LiteralDataValue,
  from Any, via {
    require CXC::Gnuplot::V0::LiteralDataValue;
    CXC::Gnuplot::V0::LiteralDataValue->assert_coerce( $_[0] );
  };

declare CoordValue, as InstanceOf ['CXC::Gnuplot::V0::CoordValue'];

coerce CoordValue, from Any, via {
    require CXC::Gnuplot::V0::CoordValue;
    CXC::Gnuplot::V0::CoordValue->assert_coerce( $_[0] );
};

declare FormatCoordSys, as Enum [FORMAT_COORD_SYS];

declare CoordOffset3D, as InstanceOf ['CXC::Gnuplot::V0::CoordOffset3D'];
coerce CoordOffset3D, from HashRef, via {
    require CXC::Gnuplot::V0::CoordOffset3D;
    CXC::Gnuplot::V0::CoordOffset3D->new( $_[0]->%* );
};

declare CoordOffset2D, as InstanceOf ['CXC::Gnuplot::V0::CoordOffset2D'];
coerce CoordOffset2D, from HashRef, via {
    require CXC::Gnuplot::V0::CoordOffset2D;
    CXC::Gnuplot::V0::CoordOffset2D->new( $_[0]->%* );
};

declare CoordPosition3D, as InstanceOf ['CXC::Gnuplot::V0::CoordPosition3D'];
coerce CoordPosition3D, from HashRef, via {
    require CXC::Gnuplot::V0::CoordPosition3D;
    CXC::Gnuplot::V0::CoordPosition3D->new( $_[0]->%* );
};

declare CoordPosition2D, as InstanceOf ['CXC::Gnuplot::V0::CoordPosition2D'];
coerce CoordPosition2D, from HashRef, via {
    require CXC::Gnuplot::V0::CoordPosition2D;
    CXC::Gnuplot::V0::CoordPosition2D->new( $_[0]->%* );
};


declare TicTimeUnits, as Enum [qw( seconds minutes hours days weeks months years )];

declare TicTimeIncr, as Dict [ multiple => PositiveNum, unit => TicTimeUnits ];
coerce TicTimeIncr,
  from Tuple [ PositiveNum, TicTimeUnits ],
  sub { my %incr; @incr{ 'multiple', 'unit' } = $_[0]->@*; return \%incr; };
declare TicIncr, as Num | TicTimeIncr, coercion => 1;

declare TicPosition, as LiteralDataValue, coercion => 1;

declare TicEntry, as    #
  Dict [
    pos   => TicPosition,
    label => Optional [Str],
    level => Optional [PositiveOrZeroInt],
  ],
  coercion => 1;

coerce TicEntry, from Num, via { { pos => TicPosition->coerce( $_[0] ) } };

declare TicEntries, as ArrayRef [TicEntry], coercion => 1;
coerce TicEntries, from TicEntry->coercibles, via {
    [ to_TicEntry( $_[0] ) ]
};

declare TicSeries, as    #
  Dict [
    start => Optional [TicPosition],
    incr  => TicIncr,
    end   => Optional [TicPosition],
  ],
  coercion => 1;

coerce TicSeries, from TicIncr, q{ { incr => $_[0] } };

declare AddTicEntries, as Tuple->of( Enum ['add'], Slurpy->of( TicEntries ) ), coercion => 1;

declare TicList, as TicEntries | AddTicEntries;

coerce TicList, from Any, via {
    eval { TicEntries->assert_coerce( $_[0] ) }
      // eval { AddTicEntries->assert_coerce( $_[0] ) }
      // $_[0]
};

declare MultiPlotLayout, as Dict( [ nrows => PositiveInt, ncols => PositiveInt ] ), message {
    require Data::Dump;
    my $value = Data::Dump::pp( $_ );
    is_ArrayRef( $_ )
      and return "$value is not an array of two positive integers";

    is_NonEmptyStr( $_ )
      and return "$value is not a string of form <PositiveInt,PositiveInt>";

    is_HashRef( $_ )
      and return "$value is not a hashref with keys 'nrows' and 'ncols'";
};

coerce MultiPlotLayout,
  ArrayRef [ PositiveInt, 2, 2 ], q{ { nrows => $_[0][0], ncols => $_[0][1] } },    #
  NonEmptyStr, <<~'EOS'
    do {
       use experimental 'builtin';
       BEGIN{ builtin::export_lexically is_PositiveInt => \&Types::Common::Numeric::is_PositiveInt };
        my ( $nrows, $ncols, $extra ) = split( qr/,/, $_[0] );
        defined $extra || !( is_PositiveInt( $nrows ) && is_PositiveInt( $ncols ) )
          ? $_[0]
          : { nrows => $nrows, ncols => $ncols };
    }
    EOS
  ;

my $PerlBool = Type::Tiny->new(
    name       => 'PerlBool',
    constraint => sub {
        use builtin 'is_bool';
        is_bool( $_ );
    } );

__PACKAGE__->add_type( $PerlBool );

__PACKAGE__->add_type(
    Type::Tiny->new(
        name       => 'PerlBoolFalse',
        parent     => $PerlBool,
        constraint => sub {
            use builtin 'false';
            $_ == false;
        } ) );

declare Fraction, as NumRange [ 0, 1, 1, 1 ];

# rgbcolor "0xRRGGBB"     # string containing hexadecimal constant
# rgbcolor "0xAARRGGBB"   # string containing hexadecimal constant
# rgbcolor "#RRGGBB"      # string containing hexadecimal in x11 format
# rgbcolor "#AARRGGBB"

declare RGBColor, as StrMatch [
    qr{^
       (?:[0][xX]|[#])
       (?:[\da-hA-H]{2}){3,4}
       $}x,
];

declare ColorSpec,
  as RGBColor | Dict [ rgbcolor => RGBColor ] | Dict [ palette => Dict [ frac => Fraction ] ];

declare Range, as InstanceOf ['CXC::Gnuplot::V0::Range'];
coerce Range, from HashRef, via {
    require CXC::Gnuplot::V0::Range;
    CXC::Gnuplot::V0::Range->new( $_[0]->%* );
};

declare Palette, as Enum( ['z'] ) | Dict [ frac => Fraction ] | Dict [ cb => Range ], coercion => 1;

declare SetFormats, as Enum [ 'array', 'flat_array', 'string' ];

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

CXC::Gnuplot::V0::Types

=head1 VERSION

version v0.29.3

=head1 INTERNALS

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
