use strict;
use warnings;
use Test::More;

use Flat::Schema;

my $profile = {
    report_version => 1,
    columns => [
        {
            index => 0,
            name  => 'id',
            type_evidence => {
                integer => 10,
            },
        },
        {
            index => 1,
            name  => 'value',
            type_evidence => {
                integer => 5,
                number  => 3,
            },
        },
        {
            index => 2,
            name  => 'when',
            type_evidence => {
                date     => 2,
                datetime => 1,
            },
        },
        {
            index => 3,
            name  => 'mixed',
            type_evidence => {
                date   => 1,
                string => 1,
            },
        },
    ],
};

my $schema = Flat::Schema->from_profile(profile => $profile);

is($schema->{columns}[0]{type}, 'integer',  'integer inferred');
is($schema->{columns}[1]{type}, 'number',   'integer+number widened to number');
is($schema->{columns}[2]{type}, 'datetime', 'date widened to datetime');
is($schema->{columns}[3]{type}, 'string',   'temporal conflict widened to string');

my @codes = map { $_->{code} } @{ $schema->{issues} };

ok(grep { $_ eq 'mixed_type_evidence' } @codes, 'mixed_type_evidence emitted');
ok(grep { $_ eq 'type_widened' } @codes,        'type_widened emitted');
ok(grep { $_ eq 'temporal_conflict_widened_to_string' } @codes,
    'temporal conflict issue emitted');

done_testing;
