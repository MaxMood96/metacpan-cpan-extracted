package CXC::Gnuplot::V1::Bound;

use v5.38;
use Object::Pad 0.821;
use experimental 'builtin';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::Bound
  : lexical_new
  : isa(CXC::Gnuplot::V1::Base) does( CXC::Gnuplot::V1::Role::Clone );

use Lexical::Import qw( Ref::Util is_plain_hashref is_ref );
use Lexical::Import qw( List::Util reduce);

use CXC::Gnuplot::V1::Types -lexical => qw(is_Num);
use CXC::Gnuplot::V1::Util -lexical => 'to_hash_r';

use Text::Balanced;
use Regexp::Common 'number', 'delimited';
use builtin 'true', 'load_module';

my $RE_quoted;
my $RE_real;
BEGIN {
    $RE_real = ${RE}{num}{real};
    use feature 'multidimensional';
    $RE_quoted = ${RE}{quoted}{ -delim => q{'"} }{-esc};    ## no critic (Multidimensional)
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

use constant Numeric  => 'CXC::Gnuplot::V1::Bound::Numeric';
use constant TimeDate => 'CXC::Gnuplot::V1::Bound::TimeDate';

use overload q{""} => 'to_string', bool => sub { true }, fallback => true;

field $lower_bound : param : reader = undef;
field $bound       : param : reader = q{*};
field $upper_bound : param : reader = undef;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

my sub is_delimited ( $str ) {
    return defined( ( Text::Balanced::extract_delimited( $str ) )[0] );
}

my sub load_subclasses {
    load_module( Numeric );
    load_module( TimeDate );
    1;
}

my sub parse_from_bound ( $bound ) {

    state $foo = load_subclasses;    ## no critic (UnusedVar)

    croak( '"bound" argument is not a scalar' )
      if is_ref( $bound );

    return Numeric->new( bound => $bound )
      if $bound =~ RE_BOUND_REAL;

    return TimeDate->new( bound => $bound )
      if $bound =~ RE_BOUND_QUOTED;

    croak "illegal bounds specification: $bound"
      unless $bound =~ RE_BOUND;

    my %args = %+;

    my $is_number = reduce { $a || $b } map { defined delete( $args{$_} ) } 'lb_real', 'ub_real';
    my $is_quoted = reduce { $a || $b } map { defined delete( $args{$_} ) } 'lb_q',    'ub_q';

    croak q{illegal bounds specification: can't mix numeric and timedate}
      if $is_number && $is_quoted;

    return Numeric->new( %args )
      if $is_number;

    return TimeDate->new( %args )
      if $is_quoted;

    return Numeric->new( %args );
}

ADJUST {
    if ( defined $bound && $bound =~ /</ ) {
        my $parsed = parse_from_bound( $bound );

        $lower_bound = $parsed->lower_bound;
        $bound       = $parsed->bound;
        $upper_bound = $parsed->upper_bound;
    }
}

method BUILDARGS : common ( @args ) {
    @args == 1 && !is_plain_hashref( $args[0] )
      and return ( bound => $args[0] );

    return $class->SUPER::BUILDARGS( @args );
}

method new : common ( @args ) {

    return &new( $class, @args )    ## no critic (Ampersand )
                                    # Object::Pad 0.825 segv's if __CLASS__ is used with a class
                                    # method so use __PACKAGE__ instead, which is fine here.
      if $class ne __PACKAGE__;

    my %arg = $class->BUILDARGS( @args );

    return parse_from_bound( $arg{bound} )
      if defined $arg{bound}
      && !defined $arg{lower_bound}
      && !defined $arg{upper_bound};

    state $foo = load_subclasses;    ## no critic (UnusedVar)

    if (   ( !defined $arg{lower_bound} || is_Num( $arg{lower_bound} ) )
        && ( !defined $arg{upper_bound} || is_Num( $arg{upper_bound} ) )
        && ( !defined $arg{bound} || is_Num( $arg{bound} ) || $arg{bound} eq q{*} ) )
    {
        return Numeric->new( %arg );
    }

    if (   ( !defined $arg{lower_bound} || is_delimited( $arg{lower_bound} ) )
        && ( !defined $arg{upper_bound} || is_delimited( $arg{upper_bound} ) )
        && ( !defined $arg{bound} || is_delimited( $arg{bound} ) || $arg{bound} eq q{*} ) )
    {
        return TimeDate->new( %arg );
    }

    croak( 'unable to construct object from arguments' );

    # what about geographic??
}

method to_hash {
    return to_hash_r( {
        ( defined $lower_bound ? ( lower_bound => $lower_bound ) : () ),
        bound => $bound,
        ( defined $upper_bound ? ( upper_bound => $upper_bound ) : () ),
    } );
}

method to_string {
    return join q{ < }, grep { defined } $lower_bound, $bound, $upper_bound;
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

CXC::Gnuplot::V1::Bound

=head1 VERSION

version v0.29.3

=head1 INTERNALS

=for Pod::Coverage BUILDARGS
DOES
META
bound
clone
lower_bound
new
to_hash
to_string
upper_bound

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
