#!perl -T

use strict;
use warnings;
use Test::More tests => 12;

use Algorithm::AhoCorasick qw(find_all);

my $found = find_all("To be or not to be", "be");
is_deeply($found, { 3 => [ "be" ], 16 => [ "be" ] });

my $mismatch = find_all("To be or not to be", "bet");
ok(!defined($mismatch));

sub test_fail {
    my $name = shift;

    eval {
	find_all(@_);
	fail($name);
    };
    if ($@) {
	ok(1, $name);
    }
}

test_fail("0 args");
test_fail("0 keywords", "To be or not to be");
test_fail("empty keyword", "To be or not to be", "be", "");

$found = find_all("To be or not to be", "be", "be");
is_deeply($found, { 3 => [ "be" ], 16 => [ "be" ] });

$mismatch = find_all("To be or not to be", 0);
ok(!defined($mismatch));

$found = find_all("Un chasseur qui sache chasser ne chase jamais sans son chien", "sa", "se", "si", "so", "su");
is_deeply($found, {
		   7 => [ "se" ],
		   16 => [ "sa" ],
		   26 => [ "se" ],
		   36 => [ "se" ],
		   46 => [ "sa" ],
		   51 => [ "so" ],
		  });

$found = find_all("Un chasseur qui sache chasser ne chase jamais sans son chien", "se", "seu");
is_deeply($found, {
		   7 => [ "se", "seu" ],
		   26 => [ "se" ],
		   36 => [ "se" ],
		  });

# RT #181060: several keywords can end at the same text index without
# actually sharing a position (different lengths mean different start
# positions) - each must land in its own bucket, deterministically.
$found = find_all("hers", "hers", "hers", "rs", "s");
is_deeply($found, { 0 => [ "hers" ], 2 => [ "rs" ], 3 => [ "s" ] });

# Keywords that really do share a start position (one a prefix of the
# next) must come back in a stable, deterministic order.
$found = find_all("Un chasseur qui sache chasser ne chase jamais sans son chien", "s", "se", "seu");
is_deeply($found, {
		   6 => [ "s" ],
		   7 => [ "s", "se", "seu" ],
		   16 => [ "s" ],
		   25 => [ "s" ],
		   26 => [ "s", "se" ],
		   36 => [ "s", "se" ],
		   44 => [ "s" ],
		   46 => [ "s" ],
		   49 => [ "s" ],
		   51 => [ "s" ],
		  });

my %seen;
for (1..50) {
    my $f = find_all("hers", "hers", "rs", "s");
    $seen{join(";", map { "$_=" . join(",", @{$f->{$_}}) } sort keys %$f)} = 1;
}
is(scalar(keys(%seen)), 1, "find_all output is deterministic across repeated calls");
