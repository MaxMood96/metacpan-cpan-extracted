#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Number::Alias qw(check_uint32);

my $self = {
        'key' => 3000000000,
};
check_uint32($self, 'key');

# Print out.
print "ok\n";

# Output:
# ok