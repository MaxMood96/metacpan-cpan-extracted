#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Array qw(check_array_items);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => ['foo', 'bar', 'baz'],
};
check_array_items($self, 'key', 2);

# Print out.
print "ok\n";

# Output like:
# #Error [..Array.pm:?] Parameter 'key' has more items than expected.