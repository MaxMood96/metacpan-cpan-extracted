use strict;
use warnings;
use Test::More;

use Flat::Schema;

sub issue_codes {
    my ($schema) = @_;
    return map { $_->{code} } @{ $schema->{issues} };
}

# Case 1: nullable iff null_count > 0
{
    my $profile = {
        report_version => 1,
        rows_profiled  => 10,
        columns => [
            { index => 0, name => 'A', rows_observed => 10, null_count => 0 },
            { index => 1, name => 'B', rows_observed => 10, null_count => 2 },
        ],
    };

    my $schema = Flat::Schema->from_profile(profile => $profile);

    is($schema->{columns}[0]{nullable}, 0, 'A: null_count=0 => nullable false');
    is($schema->{columns}[1]{nullable}, 1, 'B: null_count>0 => nullable true');

    my @codes = issue_codes($schema);
    ok(!grep { $_ eq 'no_rows_profiled' } @codes, 'no_rows_profiled not emitted');
    ok(!grep { $_ eq 'all_null_column' } @codes, 'all_null_column not emitted');
}

# Case 2: all-null column emits warning
{
    my $profile = {
        report_version => 1,
        rows_profiled  => 5,
        columns => [
            { index => 0, name => 'A', rows_observed => 5, null_count => 5 },
        ],
    };

    my $schema = Flat::Schema->from_profile(profile => $profile);

    is($schema->{columns}[0]{nullable}, 1, 'all-null => nullable true');

    my @codes = issue_codes($schema);
    ok(grep { $_ eq 'all_null_column' } @codes, 'all_null_column emitted');
}

# Case 3: zero rows profiled emits no_rows_profiled and nullable defaults true
{
    my $profile = {
        report_version => 1,
        rows_profiled  => 0,
        columns => [
            { index => 0, name => 'A', rows_observed => 0, null_count => 0 },
            { index => 1, name => 'B', rows_observed => 0, null_count => 0 },
        ],
    };

    my $schema = Flat::Schema->from_profile(profile => $profile);

    is($schema->{columns}[0]{nullable}, 1, '0 rows => nullable true (v1 edge rule)');
    is($schema->{columns}[1]{nullable}, 1, '0 rows => nullable true (v1 edge rule)');

    my @codes = issue_codes($schema);
    ok(grep { $_ eq 'no_rows_profiled' } @codes, 'no_rows_profiled emitted');
}

done_testing;
