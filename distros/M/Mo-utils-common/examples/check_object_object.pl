#!/usr/bin/env perl

use strict;
use warnings;

use Error::Pure;
use Mo::utils::common qw(check_object);
use Test::MockObject;

$Error::Pure::TYPE = 'AllError';

# Value to check.
my $value = Test::MockObject->new;

# Check.
check_object($value, 'Foo', 'Error: This is not a instance of %s.', ['Foo']);

# Output:
# ERROR: Error: This is not a instance of Foo.
# Reference: Reference: Test::MockObject
# Mo::utils::common  err                              ../common.pm               35
# main               Mo::utils::common::check_object  ../check_object_scalar.pl  13