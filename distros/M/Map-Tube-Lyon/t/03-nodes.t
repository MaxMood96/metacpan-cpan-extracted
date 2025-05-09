#!perl
use 5.14.0;
use strict;
use warnings FATAL => 'all';
use utf8;
use open ':std', ':encoding(UTF-8)';
use Test::More tests => 23;
use Map::Tube::Lyon;

my $map = new_ok( 'Map::Tube::Lyon' );

# {
#   Optional additional debug output, helps to identify mistakes in per-line station indexes
#   (watch out for stations not showing up in the data -- they may have been unceremoniously dropped!)
#   my $stationref = $map->get_stations( );
#   my @stations = @{ $stationref };
#   print STDERR "\n*******\n";
#   print STDERR join("\n", sort map { $_->id( ) } @stations ), "\n";
#   print STDERR "*** ", scalar(@stations), "\n";
#   print STDERR "*******\n";
# }

is( $map->name( ), 'Lyon métro, funiculaires et tramways', 'Name of map does not match' );

eval { $map->get_node_by_name('XYZ'); };
like( $@, qr/\QMap::Tube::get_node_by_name(): ERROR: Invalid Station Name [XYZ]\E/, 'Node XYZ should not exist' );

{
  my $ret = $map->get_node_by_name('Foch');
  isa_ok( $ret,      'Map::Tube::Node' );
  is( $ret->id( ),   'ly_s006', 'Node id not correct for station named Foch' );
  is( $ret->name( ), 'Foch',    'Node name not correct for station named Foch' );
  is( $ret->link( ), 'ly_s007,ly_s005', 'Links not correct for station named Foch' );
  is( join( ',', sort map { $_->name( ) } @{ $ret->line( ) } ),  'A', 'Line(s) not correct for station named Foch' );
}

{
  my $ret = $map->get_node_by_id('ly_s006');
  isa_ok( $ret,      'Map::Tube::Node' );
  is( $ret->id( ),   'ly_s006', 'Node id not correct for station id ly_s006' );
  is( $ret->name( ), 'Foch',    'Node name not correct for station id ly_s006' );
}

{
  my $stationref = $map->get_stations( );
  isa_ok( $stationref, 'ARRAY' );
  my @stations = @{ $stationref };
  isa_ok( ref($stations[0]),  'Map::Tube::Node' );
  is( scalar(@stations), 142, 'Number of stations incorrect for map' );
  like( join( ',', sort map { $_->name( ) } @stations ),  qr(^Alfred.*Viviani$), 'Stations not correct for map' );
}

{
  my $stationref = $map->get_stations('A');
  isa_ok( $stationref, 'ARRAY' );
  my @stations = @{ $stationref };
  isa_ok( ref($stations[0]), 'Map::Tube::Node' );
  is( scalar(@stations), 14, 'Number of stations incorrect for line A' );
  like( join( ',', sort map { $_->name( ) } @stations ),  qr(^Amp.re.*La Soie$), 'Stations not correct for line A' );
}

{
  my $stationref = $map->get_next_stations( 'Bellecour' );
  isa_ok( $stationref, 'ARRAY' );
  my @stations = @{ $stationref };
  isa_ok( $stations[0], 'Map::Tube::Node' );
  is( scalar(@stations), 4, 'Number of neighbouring stations incorrect for Bellecour' );
  like( join( ',', sort map { $_->name( ) } @stations ), qr(^Amp.re.*Saint-Jean$), 'Neighbouring stations not correct for Bellecour' );
}

