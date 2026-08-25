package CXC::Gnuplot;

# ABSTRACT: An class based interface to Gnuplot control structures

use v5.38;


our $VERSION = 'v0.29.3';

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

CXC::Gnuplot - An class based interface to Gnuplot control structures

=head1 VERSION

version v0.29.3

=head1 DESCRIPTION

B<CXC::Gnupot> is a collection of classes which model Gnuplot control
structures.  It does not invoke Gnuplot itself, just provides a means
of organizing the constructs in Gnuplot which are used to plot.

Current recommendation is to use this in cahoots with L<Gnuplot::Builder>

This module is not useful in and of itself. B<CXC::Gnuplot> uses an
explicit versioned API.  The current API is C<V1>, and is available
via L<CXC::Gnuplot::V1>.  Earlier versions I<may> receive bug fixes,
but only if they do not impact the API.

=head1 INTERNALS

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-cxc-gnuplot@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=CXC-Gnuplot>

=head2 Source

Source is available at

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot

and may be cloned from

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot.git

=head1 AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
