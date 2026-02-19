#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Binary qw(check_bytes_len);

my $self = {
        'key' => 'foo',
};
check_bytes_len($self, 'key', 3);

# Print out.
print "ok\n";

# Output:
# ok