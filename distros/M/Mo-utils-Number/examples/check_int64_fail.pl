#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_int64);
use Math::BigInt;

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => Math::BigInt->new(-30000000000000000000),
};
check_int64($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a integer between -9223372036854775808 and 9223372036854775807.