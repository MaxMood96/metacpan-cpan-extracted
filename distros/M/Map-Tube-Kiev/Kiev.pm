package Map::Tube::Kiev;

use strict;
use warnings;
use 5.006;

use File::Share ':all';
use Moo;
use namespace::clean;

our $VERSION = 0.07;

# Get XML.
has xml => (
	'is' => 'ro',
	'default' => sub {
		return dist_file('Map-Tube-Kiev', 'kiev-map.xml');
	},
);

with 'Map::Tube';

1;

__END__

=encoding utf8

=head1 NAME

Map::Tube::Kiev - Interface to the Kiev Metro Map.

=head1 SYNOPSIS

 use Map::Tube::Kiev;

 my $obj = Map::Tube::Kiev->new;
 my $routes_ar = $obj->get_all_routes($from, $to);
 my $line = $obj->get_line_by_id($line_id);
 my $line = $obj->get_line_by_name($line_name);
 my $lines_ar = $obj->get_lines;
 my $station = $obj->get_node_by_id($station_id);
 my $station = $obj->get_node_by_name($station_name);
 my $route = $obj->get_shortest_route($from, $to);
 my $stations_ar = $obj->get_stations($line);
 my $metro_name = $obj->name;
 my $xml_file = $obj->xml;

=head1 DESCRIPTION

It currently provides functionality to find the shortest route between the two
given nodes.

For more information about Kiev Map, click L<here|https://en.wikipedia.org/wiki/Kiev_Metro>.

=head1 METHODS

=head2 C<new>

 my $obj = Map::Tube::Kiev->new;

Constructor.

Returns instance of object.

=head2 C<get_all_routes> [EXPERIMENTAL]

 my $routes_ar = $obj->get_all_routes($from, $to);

Get all routes from station to station.

Returns reference to array with L<Map::Tube::Route> objects.

=head2 C<get_line_by_id>

 my $line = $obj->get_line_by_id($line_id);

Get line object defined by id.

Returns L<Map::Tube::Line> object.

=head2 C<get_line_by_name>

 my $line = $obj->get_line_by_name($line_name);

Get line object defined by name.

Returns L<Map::Tube::Line> object.

=head2 C<get_lines>

 my $lines_ar = $obj->get_lines;

Get lines in metro map.

Returns reference to unsorted array with L<Map::Tube::Line> objects.

=head2 C<get_node_by_id>

 my $station = $obj->get_node_by_id($station_id);

Get station node by id.

Returns L<Map::Tube::Node> object.

=head2 C<get_node_by_name>

 my $station = $obj->get_node_by_name($station_name);

Get station node by name.

Returns L<Map::Tube::Node> object.

=head2 C<get_shortest_route>

 my $route = $obj->get_shortest_route($from, $to);

Get shortest route between C<$from> and C<$to> node names. Node names in C<$from> and C<$to> are case insensitive.

Returns Map::Tube::Route object.

=head2 C<get_stations>

 my $stations_ar = $obj->get_stations($line);

Get list of stations for concrete metro line.

Returns reference to array with L<Map::Tube::Node> objects.

=head2 C<name>

 my $metro_name = $obj->name;

Get metro name.

Returns string with metro name.

=head2 C<xml>

 my $xml_file = $obj->xml;

Get XML specification of Kiev metro.

Returns string with XML.

=head1 EXAMPLE1

=for comment filename=print_kiev_route.pl

 use strict;
 use warnings;

 use Encode qw(decode_utf8 encode_utf8);
 use Map::Tube::Kiev;

 # Object.
 my $obj = Map::Tube::Kiev->new;

 # Get route.
 my $route = $obj->get_shortest_route(decode_utf8('Берестейська'), decode_utf8('Оболонь'));

 # Print out type.
 print "Route: ".encode_utf8($route)."\n";

 # Output:
 # Route: Берестейська (Святошинсько-Броварська лінія), Шулявська (Святошинсько-Броварська лінія), Політехнічний інститут (Святошинсько-Броварська лінія), Вокзальна (Святошинсько-Броварська лінія), Університет (Святошинсько-Броварська лінія), Театральна (Святошинсько-Броварська лінія), Хрещатик (Святошинсько-Броварська лінія), Поштова площа (Куренівсько-Червоноармійська лінія), Контрактова площа (Куренівсько-Червоноармійська лінія), Тараса Шевченка (Куренівсько-Червоноармійська лінія), Петрівка (Куренівсько-Червоноармійська лінія), Оболонь (Куренівсько-Червоноармійська лінія)

=head1 EXAMPLE2

=for comment filename=print_kiev_def_xml_file.pl

 use strict;
 use utf8;
 use warnings;

 use Map::Tube::Kiev;

 # Object.
 my $obj = Map::Tube::Kiev->new;

 # Get XML file.
 my $xml_file = $obj->xml;

 # Print out XML file.
 print "XML file: $xml_file\n";

 # Output like:
 # XML file: .*/kiev-map.xml

=head1 EXAMPLE3

=for comment filename=print_kiev_image.pl

 use strict;
 use warnings;

 use Map::Tube::GraphViz;
 use Map::Tube::GraphViz::Utils qw(node_color_without_label);
 use Map::Tube::Kiev;

 # Object.
 my $obj = Map::Tube::Kiev->new;

 # GraphViz object.
 my $g = Map::Tube::GraphViz->new(
         'callback_node' => \&node_color_without_label,
         'driver' => 'neato',
         'tube' => $obj,
 );

 # Get graph to file.
 $g->graph('Kiev.png');

 # Print file.
 system "ls -l Kiev.png";

 # Output like:
 # -rw-r--r-- 1 skim skim 162811 23. led 20.26 Kiev.png

=begin html

<a href="https://raw.githubusercontent.com/michal-josef-spacek/Map-Tube-Kiev/master/images/Kiev.png">
  <img src="https://raw.githubusercontent.com/michal-josef-spacek/Map-Tube-Kiev/master/images/Kiev.png" alt="Київський метрополітен" width="300px" height="300px" />
</a>

=end html

=head1 EXAMPLE4

=for comment filename=print_kiev_lines.pl

 use strict;
 use warnings;

 use Encode qw(encode_utf8);
 use Map::Tube::Kiev;

 # Object.
 my $obj = Map::Tube::Kiev->new;

 # Get lines.
 my $lines_ar = $obj->get_lines;

 # Print out.
 map { print encode_utf8($_->name)."\n"; } sort @{$lines_ar};

 # Output:
 # Куренівсько-Червоноармійська лінія
 # Святошинсько-Броварська лінія
 # Сирецько-Печерська лінія

=head1 EXAMPLE5

=for comment filename=print_kiev_line_stations.pl

 use strict;
 use warnings;

 use Encode qw(decode_utf8 encode_utf8);
 use Map::Tube::Kiev;

 # Arguments.
 if (@ARGV < 1) {
         print STDERR "Usage: $0 line\n";
         exit 1;
 }
 my $line = decode_utf8($ARGV[0]);

 # Object.
 my $obj = Map::Tube::Kiev->new;

 # Get stations for line.
 my $stations_ar = $obj->get_stations($line);

 # Print out.
 map { print encode_utf8($_->name)."\n"; } @{$stations_ar};

 # Output:
 # Usage: __PROG__ line

 # Output with 'foo' argument.
 # Map::Tube::get_stations(): ERROR: Invalid Line Name [foo]. (status: 105) file __PROG__ on line __LINE__

 # Output with 'Сирецько-Печерська лінія' argument.
 # Сирець
 # Дорогожичі
 # Лук'янівська
 # Золоті ворота
 # Палац спорту
 # Кловська
 # Печерська
 # Дружби народів
 # Видубичі
 # Славутич
 # Осокорки
 # Позняки
 # Харківська
 # Вирлиця
 # Бориспільська
 # Червоний хутір

=head1 DEPENDENCIES

L<File::Share>,
L<Map::Tube>,
L<Moo>,
L<namespace::clean>.

=head1 SEE ALSO

=over

=item L<Map::Tube>

Core library as Role (Moo) to process map data.

=item L<Task::Map::Tube>

Install the Map::Tube modules.

=item L<Task::Map::Tube::Metro>

Install the Map::Tube concrete metro modules.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Map-Tube-Kiev>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2014-2025 Michal Josef Špaček

Artistic License

BSD 2-Clause License

=head1 VERSION

0.07

=cut
