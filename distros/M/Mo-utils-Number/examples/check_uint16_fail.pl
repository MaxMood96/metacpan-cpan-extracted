#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_uint16);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => 300000,
};
check_uint16($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 65535.