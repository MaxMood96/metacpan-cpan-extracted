#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Number::Alias qw(check_uint64);

my $self = {
        'key' => 200000000000,
};
check_uint64($self, 'key');

# Print out.
print "ok\n";

# Output:
# ok