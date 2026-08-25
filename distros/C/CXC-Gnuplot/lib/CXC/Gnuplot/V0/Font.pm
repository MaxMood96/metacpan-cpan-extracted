package CXC::Gnuplot::V0::Font;

use v5.38;
use experimental 'declared_refs';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::Font;

no namespace::clean;

use Ref::Util 'is_ref';

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical, 'is_PositiveInt';
use CXC::Gnuplot::V0::Util -lexical => 'assert_coerce_object', 'clone_object', 'to_hash_r', 'quote';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $name  :param  :reader = undef;
field $size  :param  :reader = undef;
#>>>














ADJUST {

    defined $name
      and !length $name
      and croak( '"name" must be non-empty' );

    defined $size
      and !is_PositiveInt( $size )
      and croak( '"size" must be a positive integer' );

}





method to_hash ( %args ) {
    to_hash_r( {
        ( defined $name ? ( name => $name ) : () ),    #
        ( defined $size ? ( size => $size ) : () ),
    } );
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}





method opts {
    my $font = join( q{,}, $name // q{}, $size // () );
    return ( length( $font ) ? quote( $font ) : () );
}





sub coerce_attrs ( $class, @attrs ) {

    return undef if @attrs > 1 || is_ref( $attrs[0] );

    my %args;
    ## no critic( SplitQuotedPattern )
    @args{ 'font', 'size' } = split( $attrs[0] );
    return \%args;

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

CXC::Gnuplot::V0::Font

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 name

=head2 size

=head1 CLASS METHODS

=head2 new

=head2 assert_coerce

=head2 coerce_attrs

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
