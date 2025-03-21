#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use_ok 'Chemistry::PeriodicTable';

my $obj = new_ok 'Chemistry::PeriodicTable';

my $got = $obj->as_file;
ok -e $got, 'as_file';

$got = $obj->header;
is @$got, 22, 'header';

$got = $obj->symbols;
is_deeply [ @{ $got->{H} }[0,1] ], [1, 'Hydrogen'], 'symbols';

is $obj->number('H'), 1, 'number';
is $obj->number('hydrogen'), 1, 'number';

is $obj->name(1), 'Hydrogen', 'name';
is $obj->name('H'), 'Hydrogen', 'name';

is $obj->symbol(1), 'H', 'symbol';
is $obj->symbol('hydrogen'), 'H', 'symbol';

is $obj->value('H', 'weight'), 1.00794, 'weight';
is $obj->value(118, 'weight'), 294, 'weight';
is $obj->value('hydrogen', 'Atomic Radius'), 0.79, 'Atomic Radius';

done_testing();
