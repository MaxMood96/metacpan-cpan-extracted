package CXC::Gnuplot::V0::AxisMinorTics;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::AxisMinorTics;

no namespace::clean;

use Ref::Util 'is_ref', 'is_plain_hashref';

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical, qw(
  Enum
  Tuple
  PositiveOrZeroInt
  TicTimeIncr
);
use CXC::Gnuplot::V0::Util -lexical, 'assert_coerce_object', 'clone_object', 'pvalidate';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $intervals     :param  :reader  = undef;  # { freq | "default" }
field $time          :param  :reader  = undef;  # { <N> <units> }
#>>>














ADJUST {

    defined $intervals
      and defined $time
      and croak( q{specify only one of 'intervals' or 'time'} );

    pvalidate( intervals => Enum ['default'] | PositiveOrZeroInt, \$intervals );
    pvalidate( time      => TicTimeIncr,                          \$time );
}






method to_hash {

    return {
        ( defined $intervals ? ( intervals => $intervals ) : () ),    #
        ( defined $time      ? ( time      => $time )      : () ),
    };
}





sub assert_coerce ( $class, @args ) {

    if ( @args == 1 ) {
        my $value = pop @args;
        return $value if $value isa $class;

        @args
          = is_plain_hashref $value
          ? $value->%*
          : ( intervals => $value );
    }

    return $class->new( @args );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}






method opts {
    my @opts;

    defined $intervals
      and push @opts, [$intervals];

    defined $time
      and push @opts, [ time => [ $time->@{ 'multiple', 'unit' } ] ];

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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

CXC::Gnuplot::V0::AxisMinorTics

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 intervals

=head2 time

=head1 CLASS METHODS

=head2 new

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
