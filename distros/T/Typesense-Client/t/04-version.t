# PURPOSE: Verify version parsing and comparison (pure logic, no server)
# LAYER:   unit
# COVERS:  Typesense::Client::Version

use v5.38;
use warnings;
use Test::More;

use Typesense::Client::Version;

sub v ($string) { Typesense::Client::Version->new(version_string => $string) }

subtest 'Typesense is not strictly semver' => sub {
    ## What a real Typesense 28 reports: two components, not three.
    my $v = v('28.0');
    is("$v", '28.0', 'stringifies to what the server said');
    is($v->major, 28, 'major');
    is($v->minor, 0,  'minor');
    is($v->patch, 0,  'the missing component is zero, not an error');

    ## And a release candidate, which is not numeric at all in its tail.
    my $rc = v('28.0.rc35');
    is("$rc", '28.0.rc35', 'the full string is kept');
    is($rc->major, 28, 'the numeric part still parses');
    is($rc->patch, 0,  'the non-numeric tail is ignored for comparison');

    ## Never die: an unreachable or odd server must not take the caller down.
    my $junk = v('');
    is($junk->major, 0, 'an empty version string is zeroes, not a die');
    is($junk->comparator, '000000000', 'and still comparable');
};

subtest 'comparator makes versions sort correctly' => sub {
    is(v('28.0')->comparator,  '028000000', '28.0');
    is(v('0.19.0')->comparator,'000019000', '0.19.0');
    is(v('9.0')->comparator,   '009000000', '9.0');

    ## The reason the comparator exists: neither of the obvious comparisons
    ## works. Numerically 28.0 == 28.0.1, and as plain strings '9.0' gt '28.0'.
    ok(v('9.0')->comparator lt v('28.0')->comparator,
       '9.0 sorts before 28.0, which plain string comparison gets wrong');
    ok(v('28.0')->comparator lt v('28.0.1')->comparator,
       '28.0 sorts before 28.0.1, which numeric comparison gets wrong');
};

subtest 'is_at_least' => sub {
    my $v = v('28.0');
    ok($v->is_at_least('27.0'),  'newer than an older release');
    ok($v->is_at_least('28.0'),  'equal counts as at least');
    ok($v->is_at_least('0.19.0'),'newer than the ancient one');
    ok(!$v->is_at_least('28.1'), 'not newer than a later minor');
    ok(!$v->is_at_least('29.0'), 'not newer than the next major');
    ok($v->is_at_least(v('27.0')), 'takes another version object too');
};

done_testing();
