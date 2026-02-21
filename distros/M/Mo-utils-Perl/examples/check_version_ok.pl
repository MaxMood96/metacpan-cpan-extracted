#!/usr/bin/env perl

use strict;
use warnings;

use Mo::utils::Perl qw(check_version);

my $self = {
        'key' => '0.01',
};
check_version($self, 'key');

# Print out.
print "ok\n";

# Output:
# ok