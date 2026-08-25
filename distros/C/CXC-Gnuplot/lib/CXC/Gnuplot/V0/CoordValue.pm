package CXC::Gnuplot::V0::CoordValue;

# ABSTRACT: A Coordinate Value, with optional coordinate system

use v5.38;
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::CoordValue;

no namespace::clean;

use CXC::Gnuplot::V0::Types -lexical => 'CoordSys', 'CoordValue';
use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'pvalidate',
  'to_hash_r',
  ;

use experimental 'builtin';
use builtin 'true';
use Ref::Util 'is_plain_hashref', 'is_plain_arrayref', 'is_ref';

use namespace::clean;

use overload q{""} => \&stringify, bool => sub { true }, fallback => true;







#<<< no tidy
field $value    :param :reader;
field $coordsys :param :reader = undef;
field $string;
#>>>

ADJUST {

    pvalidate( value    => LiteralDataValue => \$value );
    pvalidate( coordsys => CoordSys, \$coordsys );

    $string = defined( $coordsys ) ? "$coordsys $value" : $value . q{};
}









sub coerce_attrs ( $class, @arg ) {

    if ( @arg == 1 ) {
        my $value = $arg[0];

        return $value if is_plain_hashref( $value );

        return { coordsys => $value->[0], value => $value->[1] }
          if is_plain_arrayref( $value ) && $value->@* == 2;

        return { value => $value }
          if !is_ref( $value );

    }

    return undef;
}






sub assert_coerce( $class, @args ) {
    assert_coerce_object( $class, @args );
}





method to_hash {

    to_hash_r( {
        value => $value->value,
        ( defined $coordsys ? ( coordsys => $coordsys ) : () ),
    } );
}









method stringify {
    return $string;
}


1;

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory coordsys

=head1 NAME

CXC::Gnuplot::V0::CoordValue - A Coordinate Value, with optional coordinate system

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 value

=head2 coordsys

=head1 CONSTRUCTORS

=head2 new

=head1 CLASS METHODS

=head2 coerce_attrs

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 stringify

   $str = $value->stringify;

Return a Gnuplot safe representation of the value.

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
