use strict;
use warnings;
use Test::More;

use Flat::Schema;

sub codes_for {
    my ($schema) = @_;
    return map { $_->{code} } @{ $schema->{issues} };
}

my $profile = {
    report_version => 1,
    rows_profiled  => 10,
    columns => [
        {
            index => 0,
            name  => 'id',
            rows_observed => 10,
            null_count    => 0,
            type_evidence => { integer => 10 },
        },
        {
            index => 1,
            name  => 'when',
            rows_observed => 10,
            null_count    => 2,
            type_evidence => { date => 10 },
        },
    ],
};

my $schema = Flat::Schema->from_profile(
    profile => $profile,
    overrides => [
        { column_index => 0, set => { type => 'string', nullable => 1, name => 'ID', length => { min => 1, max => 12 } } },
        { column_index => 1, set => { nullable => 0 } },
    ],
);

is($schema->{columns}[0]{index}, 0, 'col0 index');
is($schema->{columns}[0]{type}, 'string', 'override type applied');
is($schema->{columns}[0]{nullable}, 1, 'override nullable applied');
is($schema->{columns}[0]{name}, 'ID', 'override name applied');
is_deeply($schema->{columns}[0]{length}, { min => 1, max => 12 }, 'override length applied');

ok(exists $schema->{columns}[0]{overrides}, 'col0 overrides recorded');
ok(exists $schema->{columns}[0]{provenance}{overrides}, 'col0 provenance.overrides recorded');

# col1: nullable overridden to false
is($schema->{columns}[1]{nullable}, 0, 'col1 nullable override applied');

my @codes = codes_for($schema);

ok(grep { $_ eq 'override_applied' } @codes, 'override_applied emitted');
ok(grep { $_ eq 'override_conflicts_with_profile' } @codes, 'override_conflicts_with_profile emitted');

done_testing;
