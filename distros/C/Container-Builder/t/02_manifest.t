use strict;
use Test::More;

use JSON qw(decode_json);
use Crypt::Digest::SHA256 qw(sha256_hex);

use Container::Builder::Manifest;

my $manifest_builder = Container::Builder::Manifest->new();
my @layers = ();
my $digest = sha256_hex("hehehehe");
my $json = $manifest_builder->generate_manifest($digest, 8, \@layers);
my $manifest = decode_json($json);

ok($manifest->{schemaVersion} == 2, 'version is 2');
ok($manifest->{mediaType} eq 'application/vnd.oci.image.manifest.v1+json', 'media type is correct');
ok($manifest->{config}->{mediaType} eq 'application/vnd.oci.image.config.v1+json', 'config media type is correct');
ok($manifest->{config}->{digest} eq 'sha256:' . $digest, 'digest is as expected');
ok($manifest->{config}->{size} == 8, 'size is as expected');
ok(ref($manifest->{layers}) eq 'ARRAY', 'layers is an array');
ok(@{$manifest->{layers}} == 0, 'layers is empty');

done_testing;
