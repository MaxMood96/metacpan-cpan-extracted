#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_int32);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => -30000000000,
};
check_int32($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a integer between -2147483648 and 2147483647.