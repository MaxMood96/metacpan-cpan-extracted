#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Array qw(check_array_items);

my $self = {
        'key' => ['foo'],
};
check_array_items($self, 'key', 3);

# Print out.
print "ok\n";

# Output:
# ok