package CXC::Gnuplot::V0::LiteralDataValue;

# ABSTRACT: a literal data value, either numeric or a date

use v5.38;
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';


class CXC::Gnuplot::V0::LiteralDataValue;

no namespace::clean;

use Scalar::Util 'looks_like_number';
use Ref::Util 'is_hashref', 'is_ref';
use experimental 'builtin';
use builtin 'true';

use namespace::clean;

use overload q{""} => \&stringify, bool => sub { true }, fallback => true;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}





field $value : param : reader;
field $string;

ADJUST {

    is_ref( $value )
      and croak( 'value must be a scalar' );

    require B;
    $string = looks_like_number( $value ) ? $value : B::cstring( $value );
}









sub assert_coerce ( $class, @arg ) {

    if ( @arg == 1 ) {
        my $value = pop @arg;
        return $value if $value isa $class;

        @arg = is_hashref $value ? $value->%* : ( value => $value );
    }


    return $class->new( @arg );

}




method to_hash {
    { value => $value }
}











method stringify {
    return $string;
}


1;

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

CXC::Gnuplot::V0::LiteralDataValue - a literal data value, either numeric or a date

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 value

=head1 CONSTRUCTORS

=head2 new

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 stringify

   $str = $value->stringify;

Return a Gnuplot safe representation of the value.  Numerical values
are returned as is; non-numerical values are returned as double-quoted
strings with escaped sequences for non-printable characters (via B::cstring)

=head1 INTERNALS

=for Pod::Coverage DOES
META

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
