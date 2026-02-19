#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Number::Alias qw(check_uint16);

my $self = {
        'key' => 60000,
};
check_uint16($self, 'key');

# Print out.
print "ok\n";

# Output:
# ok