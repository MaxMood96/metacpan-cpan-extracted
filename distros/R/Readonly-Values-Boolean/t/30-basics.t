#!/usr/bin/env perl
use strict;
use warnings;
use Test::Most;

# Test the module can be loaded
BEGIN {
	use_ok('Readonly::Values::Boolean') or BAIL_OUT('Cannot load Readonly::Values::Boolean');
}

# Import all exported symbols
use Readonly::Values::Boolean;

# Test constants are defined and have correct values
subtest 'Boolean constants' => sub {
	ok(defined $FALSE, '$FALSE is defined');
	ok(defined $TRUE, '$TRUE is defined');

	# Test values are sequential starting from 1
	is($FALSE, 0, '$FALSE equals 0');
	is($TRUE, 1, '$TRUE equals 1');

	# Test constants are readonly
	throws_ok { $FALSE = 99 } qr/Modification of a read-only value/,
		'$MON is readonly';
};

# Test %booleans hash
subtest 'Booleans hash' => sub {
	for my $false ('false', 'FALSE', 'off', '0', 'no', 0) {
		is($booleans{$false}, $FALSE, "$false maps to FALSE");
		is($booleans{$false}, 0, "$false maps to 0");
	}
	for my $true ('true', 'TRUE', 'on', '1', 'yes', 1) {
		is($booleans{$true}, $TRUE, "$true maps to TRUE");
		is($booleans{$true}, 1, "$true maps to 1");
	}

	# Test hash is readonly
	throws_ok { $booleans{'ON'} = 99 } qr/Modification of a read-only value/,
		'%booleans is readonly';
	# Test expected number of entries
	is(scalar keys %booleans, 10, '%booleans has 10 entries');
};

# Test exports
subtest 'Exports' => sub {
	# Test that all expected symbols are exported
	my @expected_exports = qw(
		$FALSE $TRUE
		%booleans
	);

	# Check constants are accessible
	ok(defined $FALSE, '$TRUE is exported');
	ok(defined $TRUE, '$TRUE is exported');

	# Check hash is accessible
	ok(%booleans, '%booleans is exported');
};

# Test practical usage scenarios
subtest 'Usage scenarios' => sub {
	# Test iteration over day names (from synopsis)
	my $value = $Readonly::Values::Boolean::booleans{'false'};

	ok($value == 0);
};

# Test module metadata
subtest 'Module metadata' => sub {
	ok(defined $Readonly::Values::Boolean::VERSION, 'Version is defined');
};

# Test edge cases and error conditions
subtest 'Edge cases' => sub {
	# Test non-existent keys
	ok(!exists $booleans{'invalid'}, 'Non-existent key returns false');
	is($booleans{'invalid'}, undef, 'Non-existent key returns undef');

	# Test empty string
	ok(!exists $booleans{''}, 'Empty string key returns false');

	# Test case variations that should not exist
	ok(!exists $booleans{'False'}, 'Capitalized abbreviations do not exist');
};

done_testing();
