#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Number::Alias qw(check_int64);

my $self = {
        'key' => -2,
};
check_int64($self, 'key');

# Print out.
print "ok\n";

# Output:
# ok