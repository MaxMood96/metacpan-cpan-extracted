use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Exception;
use Uniform::Utils qw(normalize_http_headers parse_size_limit);

# 1. Setup a complex mock environment combining every edge case your code catches
my $messy_environment = {
    'HTTP_HX_TARGET' => 'loser-env-variable',
    'HX-Target'      => 'winner-real-header',
    '  hx_boosted  ' => 'true',
    'hx-trigger'     => [ 'ignored-first-id', 'winning-last-id' ],
    'hx-evil-inject; content' => 'should-be-dropped-entirely',
};

my $normalized = normalize_http_headers($messy_environment);

# 2. Assert structural correctness using Test::Deep
cmp_deeply(
    $normalized,
    {
        'hx-target'  => 'winner-real-header', # Score ranking victory
        'hx-boosted' => 'true',               # Whitespace and case cleanup
        'hx-trigger' => 'winning-last-id',    # Array reduction filter
    },
    'Centralized normalization engine processes edge cases flawlessly'
);

# --- parse_size_limit ---
is(parse_size_limit('2048'), 2048, 'parse_size_limit accepts a plain byte count');
is(parse_size_limit('2K'), 2048, 'parse_size_limit converts K (kilobytes, 1024-based)');
is(parse_size_limit('2M'), 2 * 1024**2, 'parse_size_limit converts M (megabytes, 1024-based)');
is(parse_size_limit('1g'), 1024**3, 'parse_size_limit is case-insensitive on the unit suffix');

throws_ok { parse_size_limit(undef) } 'Uniform::Exceptions',
    'parse_size_limit throws when given undef';
throws_ok { parse_size_limit('') } 'Uniform::Exceptions',
    'parse_size_limit throws when given an empty string';
throws_ok { parse_size_limit('not-a-size') } 'Uniform::Exceptions',
    'parse_size_limit throws when given an unparsable string';

done_testing();
