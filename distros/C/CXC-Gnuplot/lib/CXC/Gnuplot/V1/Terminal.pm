package CXC::Gnuplot::V1::Terminal;

use v5.38;

our $VERSION = 'v0.29.3';

use experimental 'builtin', 'declared_refs';
use builtin::compat 'load_module', 'true';

no namespace::clean;
use Ref::Util 'is_plain_hashref';
use namespace::clean;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}





sub new ( $class, %arg ) {
    my $terminal = delete( $arg{terminal} )
      // croak( 'unspecified terminal type; missing "terminal" attribute' );

    $class .= q{::} . $terminal;

    load_module( $class );
    return $class->new( %arg );
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

CXC::Gnuplot::V1::Terminal

=head1 VERSION

version v0.29.3

=head1 CONSTRUCTORS

=head2 new

=head1 INTERNALS

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
