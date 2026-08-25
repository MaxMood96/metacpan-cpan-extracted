package CXC::Gnuplot::V1::MultiPlot;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::MultiPlot : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use builtin 'true', 'false';

use CXC::Gnuplot::V1::Util
  -lexical => 'maybe_quote',
  'pvalidate',   'pvalidate_xy_pair', 'to_hash_r',
  'render_opts', 'render_set',        'flatten_array';

use CXC::Gnuplot::V1::Types
  -lexical => 'Dict',
  'Enum',
  'Maybe',
  'MultiPlotLayout',
  'Num',
  'Optional',
  'SetFormats',
  'signature_for';

no namespace::clean;

use Ref::Util 'is_hashref';

use constant XYPair => Num | Dict [ x => Num, y => Optional [ Maybe [Num] ] ];

use namespace::clean;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $title      :param  :reader  = undef;
field $layout     :param  :reader  = undef;
field $order      :param  :reader  = undef;
field $direction  :param  :reader  = undef;
field $scale      :param  :reader  = undef;
field $offset     :param  :reader  = undef;
field $margins    :param  :reader  = undef;
field $spacing    :param  :reader  = undef;
#>>>

























ADJUST {

    pvalidate( title   => 'MultiPlot::Title'   => \$title );
    pvalidate( margins => 'MultiPlot::Margins' => \$margins );

    pvalidate_xy_pair( spacing => XYPair, \$spacing );
    defined $spacing
      and !defined $spacing->{y}
      and delete $spacing->{y};

    pvalidate_xy_pair( offset => XYPair, \$offset );
    defined $offset
      and !defined $offset->{y}
      and delete $offset->{y};

    pvalidate_xy_pair( scale => XYPair, \$scale );
    defined $scale
      and !defined $scale->{y}
      and delete $scale->{y};

    pvalidate( order     => Enum [ 'rowsfirst', 'columnsfirst' ], \$order );
    pvalidate( direction => Enum [ 'downwards', 'upwards' ],      \$direction );

    pvalidate( layout => MultiPlotLayout, \$layout );
}



















method to_hash {

    to_hash_r( {
        ( defined $title     ? ( title     => $title )          : () ),
        ( defined $layout    ? ( layout    => { $layout->%* } ) : () ),
        ( defined $order     ? ( order     => $order )          : () ),
        ( defined $direction ? ( direction => $direction )      : () ),
        ( defined $scale     ? ( scale     => $scale )          : () ),
        ( defined $offset    ? ( offset    => $offset )         : () ),
        ( defined $margins   ? ( margins   => $margins )        : () ),
        ( defined $spacing   ? ( spacing   => $spacing )        : () ),
    } );
}






signature_for opts => (
    method => 1,
    named  => [
        as => SetFormats,
        { default => 'array' },
    ],
);

method opts ( $opt ) {

    my @opts;

    push @opts, render_opts( title => $title );

    if ( defined $layout ) {

        push @opts, [ layout => join( q{,}, $layout->{nrows}, $layout->{ncols} ) ];

        defined $order
          and push @opts, $order;

        defined $direction
          and push @opts, $direction;

        defined $scale
          and push @opts, [ scale => join( q{,}, grep defined, $scale->@{ 'x', 'y' } ) ];

        defined $offset
          and push @opts, [ offset => join( q{,}, grep defined, $offset->@{ 'x', 'y' } ) ];

        push @opts, render_opts( margins => $margins );

        defined $spacing
          and push @opts, [ spacing => join( q{,}, grep defined, $spacing->@{ 'x', 'y' } ) ];
    }


    return
        $opt->as eq 'array'         ? @opts
      : $opt->as eq 'flatten_array' ? map { flatten_array( $_ ) } @opts
      : $opt->as eq 'string'        ? join q{ }, map { flatten_array( $_ )->@* } @opts
      :                               croak( 'unknown format: ' . $opt->as );
}





signature_for set => (
    method => 1,
    named  => [
        as => SetFormats,
        { default => 'string' },
    ],
);

method set ( $opt ) {
    return render_set( [ render_opts( [ set => 'multiplot' ], $self ) ], $opt->as );
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory logscale logscalebase

=head1 NAME

CXC::Gnuplot::V1::MultiPlot

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 title

=head2 layout

=head2 order

=head2 direction

=head2 scale

=head2 offset

=head2 margins

=head2 spacing

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash reference.

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
