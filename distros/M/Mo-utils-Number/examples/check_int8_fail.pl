#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_int8);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => -300,
};
check_int8($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a integer between -128 and 127.