#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::Perl qw(check_version);

$Error::Pure::TYPE = 'Error';

my $self = {
        'key' => 'bad',
};
check_version($self, 'key');

# Print out.
print "ok\n";

# Output like:
# #Error [..Perl.pm:?] Parameter 'key' isn't right Perl version.