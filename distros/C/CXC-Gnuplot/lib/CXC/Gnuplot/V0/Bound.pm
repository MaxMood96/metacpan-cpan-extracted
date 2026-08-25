package CXC::Gnuplot::V0::Bound;

use v5.38;
use experimental 'builtin';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';
## no critic(Community::MultidimensionalArrayEmulation)

class CXC::Gnuplot::V0::Bound;

no namespace::clean;

use Ref::Util 'is_plain_hashref', 'is_ref';
use List::Util 'reduce';

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical => qw(is_Num);
use CXC::Gnuplot::V0::Util -lexical => 'clone_object', 'to_hash_r';

use Text::Balanced;

use overload
  q{""}    => 'to_string',
  bool     => sub { builtin::true },
  fallback => builtin::false;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $lower_bound  :param  :reader  = undef;
field $bound        :param  :reader  = q{*};
field $upper_bound  :param  :reader  = undef;
#>>>



















method to_hash {
    to_hash_r( {
        ( defined $lower_bound ? ( lower_bound => $lower_bound ) : () ),
        ( defined $upper_bound ? ( upper_bound => $upper_bound ) : () ),
        ( defined $bound       ? ( bound       => $bound )       : () ),
    } );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}


my sub is_delimited ( $str ) {
    return defined( ( Text::Balanced::extract_delimited( $str ) )[0] );
}

my sub is_timedate( $str ) {
    return defined( ( Text::Balanced::extract_delimited( $str ) )[0] );
}





sub assert_coerce ( $class, @arg ) {

    require CXC::Gnuplot::V0::Bound::Numeric;
    require CXC::Gnuplot::V0::Bound::TimeDate;

    return $class->new_from_string( $arg[0] )
      if @arg == 1 && !is_ref( $arg[0] );

    return $arg[0]
      if @arg == 1 && $arg[0] isa $class;

    my %arg
      = @arg == 1
      ? is_plain_hashref( $arg[0] )
          ? $arg[0]->%*
          : croak( 'unable to coerce ' . ref $arg[0] )
      : @arg;

    return CXC::Gnuplot::V0::Bound::Numeric->new( %arg )
      if ( !defined $arg{min} || is_Num( $arg{min} ) )
      && ( !defined $arg{max} || is_Num( $arg{max} ) );

    return CXC::Gnuplot::V0::Bound::TimeDate->new( %arg )
      if ( !defined $arg{min} || is_delimited( $arg{min} ) )
      && ( !defined $arg{max} || is_delimited( $arg{max} ) );

    croak( 'unable to coerce' );

    # what about geographic??

}





use Regexp::Common 'number', 'delimited';

my $RE_quoted;
my $RE_real;
BEGIN {
    $RE_real = ${RE}{num}{real};
    use feature 'multidimensional';
    $RE_quoted = ${RE}{quoted}{ -delim => q{'"} }{-esc};
}

## no critic(RegularExpressions::ProhibitComplexRegexes)
use constant RE_BOUND_REAL   => qr/^$RE_real$/;
use constant RE_BOUND_QUOTED => qr/^$RE_quoted$/;

use constant RE_BOUND => qr{
               ^
                 (?:
                     (?<lower_bound> (?<lb_real>$RE_real) | (?<lb_q>$RE_quoted))
                     \s* <
                 )?
                 \s* (?<bound>[*]) \s*
                 (?: <
                     \s*
                     (?<upper_bound> (?<ub_real>$RE_real) | (?<ub_q>$RE_quoted))
                 )?
                 $ }x;


sub new_from_string( $class, $str ) {

    require CXC::Gnuplot::V0::Bound::Numeric;
    require CXC::Gnuplot::V0::Bound::TimeDate;


    croak( '"str" argument is not a scalar' )
      if is_ref( $str );

    return CXC::Gnuplot::V0::Bound::Numeric->new( bound => $str )
      if $str =~ RE_BOUND_REAL;

    return CXC::Gnuplot::V0::Bound::TimeDate->new( bound => $str )
      if $str =~ RE_BOUND_QUOTED;

    croak "illegal bounds specification: $str"
      unless $str =~ RE_BOUND;

    my %args = %+;

    # need to delete these from %args, so can't use short-circuit boolean
    my $is_number = reduce { $a || $b } map { defined delete( $args{$_} ) } 'lb_real', 'ub_real';
    my $is_quoted = reduce { $a || $b } map { defined delete( $args{$_} ) } 'lb_q',    'ub_q';

    croak q{illegal bounds specification: can't mix numeric and timedate}
      if $is_number && $is_quoted;

    return CXC::Gnuplot::V0::Bound::Numeric->new( %args )
      if $is_number;

    return CXC::Gnuplot::V0::Bound::TimeDate->new( %args )
      if $is_quoted;

    return CXC::Gnuplot::V0::Bound::Numeric->new( %+ );
}






method to_string {

    return join(
        q{ < },    #
        ( defined $lower_bound ? $lower_bound : () ),
        $bound,
        ( defined $upper_bound ? $upper_bound : () ),
    );
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

CXC::Gnuplot::V0::Bound

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 lower_bound

=head2 bound

=head2 upper_bound

=head1 CLASS METHODS

=head2 new

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 to_string

=head1 SUBROUTINES

=head2 assert_coerce

=head2 new_from_string

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
