#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_uint64);
use Math::BigInt;

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => Math::BigInt->new(30000000000000000000),
};
check_uint64($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 18446744073709551615.