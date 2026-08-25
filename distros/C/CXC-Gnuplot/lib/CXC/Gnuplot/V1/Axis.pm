package CXC::Gnuplot::V1::Axis;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Axis : isa(CXC::Gnuplot::V1::Base) does( CXC::Gnuplot::V1::Role::Clone );

no namespace::clean;

use Syntax::Operator::Elem 'elem_str';
use namespace::clean;

use builtin 'is_bool', 'true';

use CXC::Gnuplot::V1::AxisFormat;
use CXC::Gnuplot::V1::Types
  -lexical => 'is_PositiveNum',
  'NonEmptyStr', 'SetFormats', 'signature_for';

use CXC::Gnuplot::V1::Util
  -lexical => 'pvalidate',
  'to_hash_r', 'render_opts',
  'render_set';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $range         :param  :reader  = undef;
field $label         :param  :reader  = undef;
field $format        :param  :reader  = undef;
field $logscale      :param  :reader  = undef;
field $logscalebase  :param  :reader  = undef;
field $data          :param  :reader  = undef;
field $tics          :param  :reader  = undef;
field $mtics         :param  :reader  = undef;

#>>>

























ADJUST {

    pvalidate( format => AxisFormat => \$format );

    pvalidate( range => AxisRange => \$range );
    pvalidate( label => AxisLabel => \$label );

    defined $tics
      and !is_bool( $tics )
      and pvalidate( tics => AxisTics => \$tics );

    defined $mtics
      and !is_bool( $mtics )
      and pvalidate( mtics => AxisMinorTics => \$mtics );

    #<<< no tidy
    defined $data
      and ! elem_str( $data, 'normal', 'time' )
      and croak( q{invalid value for "data" parameter} );
    #>>>

    defined $logscale
      and !is_bool( $logscale )
      and croak( q{invalid value for "logscale" parameter; must be bool} );

    defined $logscalebase
      and !is_PositiveNum( $logscalebase )
      and croak( q{invalid value for "logscalebase" parameter; must be positive float} );

}




















method to_hash {

    to_hash_r( {
        ( defined $range        ? ( range        => $range )        : () ),
        ( defined $label        ? ( label        => $label )        : () ),
        ( defined $format       ? ( format       => $format )       : () ),
        ( defined $logscale     ? ( logscale     => $logscale )     : () ),
        ( defined $logscalebase ? ( logscalebase => $logscalebase ) : () ),
        ( defined $data         ? ( data         => $data )         : () ),
        ( defined $tics         ? ( tics         => $tics )         : () ),
        ( defined $mtics        ? ( mtics        => $mtics )        : () ),
    } );
}





signature_for set => (
    method => 1,
    head   => [NonEmptyStr],
    named  => [
        as => SetFormats,
        { default => 'string' },
    ],
);

method set( $axis, $opt ) {

    ## no critic(NamingConventions::ProhibitAmbiguousNames)
    my @set;

    push @set, $range->set( $axis, as => $opt->as )
      if defined $range;

    push @set, render_opts( [ set => $axis . 'label' ], $label );

    push @set, render_opts( [ set => 'format', $axis ], $format );

    if ( defined $tics ) {
        my $key = $axis . 'tics';
        push @set, is_bool( $tics )
          ? $tics
              ? [ set   => $key ]
              : [ unset => $key ]
          : render_opts( [ set => $key ], $tics );
    }

    if ( defined $mtics ) {
        my $key = 'm' . $axis . 'tics';
        push @set, is_bool( $mtics )
          ? $mtics
              ? [ set   => $key ]
              : [ unset => $key ]
          : render_opts( [ set => $key ], $mtics );
    }

    push @set, [ set => $axis . 'data', ( $data eq 'normal' ? () : $data ) ]
      if defined $data;

    push @set, [ set => 'logscale', [ $axis, defined $logscalebase ? $logscalebase : () ] ]
      if defined $logscale && $logscale;

    return render_set( \@set, $opt->as );
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
mtics

=head1 NAME

CXC::Gnuplot::V1::Axis

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 data

=head2 format

=head2 label

=head2 logscale

=head2 logscalebase

=head2 mtics

=head2 range

=head2 tics

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash reference.

=head1 METHODS

=head2 to_hash

Returns a hashref whose contents can be passed to the constructor to
generate a duplicate of the object.

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
