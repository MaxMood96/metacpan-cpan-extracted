use strict;
use warnings;
use Test::More;
use Weather::NHC::TropicalCyclone::Resource ();

my $r = 'Weather::NHC::TropicalCyclone::Resource';

is $r->kind('publicAdvisory', undef), 'text', 'text resource classified';
is $r->kind('trackCone', 'kmzFile'), 'file', 'download resource classified';
is $r->kind('trackCone', 'bogus'), 'unknown', 'unknown resource/type classified';
ok $r->is_valid_file_type('peakSurgeKML', 'kmlFile'), 'peak surge kml valid';
ok !$r->is_valid_file_type('trackCone', undef), 'undefined type invalid';
ok !$r->is_valid_file_type('trackCone', 'bogus'), 'unknown type invalid';
ok !$r->is_valid_file_type('forecastTrack', 'kmlFile'), 'wrong resource/type pairing invalid';

is $r->extension_for_type('zipFile5km'), 'zip', 'zip extension';
is $r->extension_for_type('kmzFile64kt'), 'kmz', 'kmz extension';
is $r->extension_for_type('kmlFile'), 'kml', 'kml extension';
is $r->extension_for_type('bogus'), undef, 'unknown extension';

ok scalar grep( $_ eq 'forecastDiscussion', @{ $r->text_resources } ), 'text resource catalog';
ok scalar grep( $_ eq 'trackCone', @{ $r->file_types->{kmzFile} } ), 'file type catalog';

done_testing;
