#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::common qw(check_object);

$Error::Pure::TYPE = 'AllError';

# Value to check.
my $value = 'Foo';

# Check.
check_object($value, 'Foo', 'Error: This is not a instance of %s.', ['Foo']);

# Output:
# ERROR: Error: This is not a instance of Foo.
# Value: Foo
# Mo::utils::common  err                              ../common.pm               20
# main               Mo::utils::common::check_object  ../check_object_scalar.pl  12