package CXC::Gnuplot::V1::Timestamp;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Timestamp : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use builtin 'is_bool', 'true', 'false';

use CXC::Gnuplot::V1::Types -lexical, qw(
  Enum
  is_Num
  CoordOffset2D
  SetFormats

  signature_for
);

use CXC::Gnuplot::V1::Util -lexical, 'maybe_quote', 'pvalidate', 'to_hash_r', 'render_opts',
  'render_set';

use CXC::Gnuplot::V1::AxisFormat;


my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $format        :param  :reader  = undef;  #
field $where         :param  :reader  = undef;  # {top | bottom}
field $rotate        :param  :reader  = undef;  # {{no}rotate {by <ang>}}
field $offset        :param  :reader  = undef;  # {offset <offset> }
field $font          :param  :reader  = undef;  # {"name{,<size>}"}
field $textcolor     :param  :reader  = undef;  # {colorspec}
#>>>























ADJUST {

    pvalidate( format => Str => \$format );

    pvalidate( where => Enum->of( 'top', 'bottom' ), \$where );

    defined $rotate
      and !is_bool( $rotate )
      and !is_Num( $rotate )
      and croak( '"rotate" must be a float or a boolean' );

    pvalidate( offset    => CoordOffset2D, \$offset );
    pvalidate( font      => Font      => \$font );
    pvalidate( textcolor => ColorSpec => \$textcolor );
}





method to_hash {

    to_hash_r( {
        ( defined $format    ? ( format    => $format )    : () ),
        ( defined $where     ? ( where     => $where )     : () ),
        ( defined $rotate    ? ( rotate    => $rotate )    : () ),
        ( defined $offset    ? ( offset    => $offset )    : () ),
        ( defined $font      ? ( font      => $font )      : () ),
        ( defined $textcolor ? ( textcolor => $textcolor ) : () ),
    } );
}





method opts {
    my @opts;

    defined $format
      and push @opts, maybe_quote( $format );


    defined $where
      and push @opts, $where;

    defined $offset
      and push @opts, render_opts( offset => $offset );

    defined $rotate
      and push @opts, is_bool( $rotate )
      ? ( $rotate ? 'rotate' : 'norotate' )
      : [ 'rotate by' => $rotate ];


    push @opts, render_opts( font => $font );

    push @opts, render_opts( textcolor => $textcolor );

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
    return render_set( [ render_opts( [ set => 'timestamp' ], $self ) ], $opt->as );
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

CXC::Gnuplot::V1::Timestamp

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 format

=head2 where

=head2 rotate

=head2 offset

=head2 font

=head2 textcolor

=head1 CLASS METHODS

=head2 new

=head1 METHODS

=head2 to_hash

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
