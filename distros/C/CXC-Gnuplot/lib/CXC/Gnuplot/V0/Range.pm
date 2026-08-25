package CXC::Gnuplot::V0::Range;

use v5.38;
use experimental 'builtin';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::Range;

use builtin 'true';
use CXC::Gnuplot::V0::Bound;

use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'clone_object', 'pvalidate', 'render_opts';

use overload q{""} => \&stringify, fallback => true, bool => sub { 1 };

#<<< no tidy
field $min       :param  :reader  = undef;
field $max       :param  :reader  = undef;
field $string;
#>>>













my sub croak {
    require Carp;
    goto \&Carp::croak;
}

ADJUST {
    pvalidate( min => Bound => \$min );
    pvalidate( max => Bound => \$max );
}





method to_hash {
    return { ( defined $max ? ( max => $max ) : () ), ( defined $min ? ( min => $min ) : () ), };
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}









method stringify {
    ( defined( $min // $max ) ? sprintf( '[%s:%s]', $min // q{}, $max // q{} ) : () );
}





method opts {
    return $self->stringify();
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory writeback

=head1 NAME

CXC::Gnuplot::V0::Range

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 min

=head2 max

=head1 CLASS METHODS

=head2 new

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 stringify

   $str = $value->stringify;

Return a Gnuplot safe representation of the value.

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
