use strict;
use warnings;
use Test::More;

use Flat::Schema;

my $profile = {
    report_version => 1,
    null_empty     => 1,
    null_tokens    => [ '', 'NULL' ],
    columns => [
        { index => 0, name => 'A', rows_observed => 3, null_count => 1 },
        { index => 1, name => 'B', rows_observed => 3, null_count => 0 },
    ],
};

my $schema1 = Flat::Schema->from_profile(profile => $profile);
my $schema2 = Flat::Schema->from_profile(profile => $profile);

my $fs = Flat::Schema->new();

my $json1 = $fs->to_json(schema => $schema1);
my $json2 = $fs->to_json(schema => $schema2);

is($json1, $json2, 'JSON serialization is deterministic');

my $yaml1 = $fs->to_yaml(schema => $schema1);
my $yaml2 = $fs->to_yaml(schema => $schema2);

is($yaml1, $yaml2, 'YAML serialization is deterministic');

# Spot-check key ordering expectations (top-level fixed list ordering)
like($json1, qr/\A\{"schema_version":1,"generator":\{"name":"Flat::Schema","version":"0\.01"\},"profile":\{/, 'JSON begins with canonical top-level keys');

done_testing;
