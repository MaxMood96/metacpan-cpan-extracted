# -*- perl -*-
#
# Author: Gisbert W. Selke, TapirSoft Selke & Selke GbR.
#
# Copyright (C) 2015, 2025 Gisbert W. Selke. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: gws@cpan.org
#
package Map::Tube::Hamburg;
use 5.14.0;
use version 0.77 ( );
use strict;
use warnings;

our $VERSION = version->declare('v0.1.3');

=encoding utf8

=head1 NAME

Map::Tube::Hamburg - Interface to the Hamburg U- and S-Bahn maps including AKN

=cut

use File::Share ':all';
use Moo;
use namespace::clean;

has xml => ( is => 'ro', default => sub { return dist_file('Map-Tube-Hamburg', 'hamburg-map.xml') } );

with 'Map::Tube';

=head1 SYNOPSIS

	use Map::Tube::Hamburg;
	my $tube = Map::Tube::Hamburg->new();

	my $route = $tube->get_shortest_route('Hagendeel', 'Reeperbahn');

    print "Route: $route\n";

=head1 DESCRIPTION

This module allows to find the shortest route between any two given tube
stations in Hamburg. In fact, underground, S-Bahn, and AKN (Altona-Kaltenkirchen-Neumünster) lines
are covered for the wider Hamburg area.
All interesting methods are provided by the role L<Map::Tube>.

=head1 METHODS

=head2 CONSTRUCTOR

	use Map::Tube::Hamburg;
	my $tube = Map::Tube::Hamburg->new();

The only argument, C<xml>, is optional; if specified, it should be a code ref
to a function that returns either the path the XML map file, or a string
containing this XML content. The default is the path to F<hamburg-map.xml>
that is a part of this distribution. For further information see L<Map::Tube>.

=head2 xml()

This read-only accessor returns whatever was specified as the XML source at
construction.

=head1 ERRORS

If something goes wrong, maybe because the map information file was corrupted,
the constructor will die.

=head1 AUTHOR

Gisbert W. Selke, TapirSoft Selke & Selke GbR <gws@cpan.org>

=head1 COPYRIGHT AND LICENCE

The data for the XML file were mainly taken from the appropriate
OpenStreetMap maps.  They are CC BY-SA 2.0.  The module itself is free
software; you may redistribute and/or modify it under the same terms as
Perl itself.

=head1 SEE ALSO

L<Map::Tube>, L<Map::Tube::GraphViz>.

=cut

1;
