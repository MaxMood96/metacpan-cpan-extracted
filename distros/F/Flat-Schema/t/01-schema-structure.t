use strict;
use warnings;
use Test::More;

use Flat::Schema;

my $profile = {
    report_version => 1,
    columns => [
        { index => 1, name => 'B', rows_observed => 10, null_count => 2 },
        { index => 0, name => 'A', rows_observed => 10, null_count => 0 },
    ],
};

my $schema = Flat::Schema->from_profile(profile => $profile);

is(ref($schema), 'HASH', 'schema is a hashref');

ok(exists $schema->{schema_version}, 'schema_version present');
is($schema->{schema_version}, 1, 'schema_version == 1');

ok(exists $schema->{generator}, 'generator present');
is($schema->{generator}{name}, 'Flat::Schema', 'generator.name');
ok(defined $schema->{generator}{version}, 'generator.version');

ok(exists $schema->{profile}, 'profile present');
is($schema->{profile}{report_version}, 1, 'profile.report_version');

ok(exists $schema->{columns}, 'columns present');
is(ref($schema->{columns}), 'ARRAY', 'columns is arrayref');
is(scalar @{ $schema->{columns} }, 2, 'columns count');

# Determinism: ordered by index
is($schema->{columns}[0]{index}, 0, 'columns[0] index sorted');
is($schema->{columns}[1]{index}, 1, 'columns[1] index sorted');

# Contract-required keys
for my $col (@{ $schema->{columns} }) {
    ok(exists $col->{index}, 'column.index present');
    ok(exists $col->{name},  'column.name present (may be undef)');
    ok(exists $col->{type},  'column.type present');
    ok(exists $col->{nullable}, 'column.nullable present');
    ok(exists $col->{provenance}, 'column.provenance present');

    ok(!exists $col->{issues}, 'no column-level issues key (global only)');
}

# Always include issues at top level (Option B)
ok(exists $schema->{issues}, 'issues present at top level');
is(ref($schema->{issues}), 'ARRAY', 'issues is arrayref');
is(scalar @{ $schema->{issues} }, 0, 'issues empty array by default');

done_testing;
