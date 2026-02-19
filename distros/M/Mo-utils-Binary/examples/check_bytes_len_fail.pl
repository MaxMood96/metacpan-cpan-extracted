#!/usr/bin/env perl

use strict;
use utf8;
use warnings;

use Error::Pure;
use Mo::utils::Binary qw(check_bytes_len);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => '森林',
};
check_bytes_len($self, 'key', 3);

# Print out.
print "ok\n";

# Output like:
# #Error [..utils.pm:?] TODO