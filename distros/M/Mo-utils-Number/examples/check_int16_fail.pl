#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Number::Alias qw(check_int16);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => -300000,
};
check_int16($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [...Range.pm:?] Parameter 'key' must be a integer between -32768 and 32767.