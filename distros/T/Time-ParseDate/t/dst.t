#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval { require Test::MockTime };
if ($@) {
    plan skip_all => 'Test::MockTime required for this test';
}
Test::MockTime->import('set_fixed_time', 'restore_time');

use_ok( 'Time::ParseDate' );

$ENV{'LANG'} = 'C';
$ENV{'TZ'} = 'PST8PDT';

# Verify that setting $ENV{TZ} actually affects localtime() on this
# platform. Not all systems honor TZ changes within a running process.
my @x = localtime(785307957);
my @y = gmtime(785307957);
my $hd = $y[2] - $x[2];
$hd += 24 if $hd < 0;
$hd %= 24;
if ($hd != 8) {
    plan skip_all => "It seems localtime() does not honor \$ENV{TZ} when set in the test script.";
    exit 0;
}


# Verify that parsing a date returns the correct epoch regardless of
# whether the system clock and the parsed date are in different DST states.
# https://github.com/muir/Time-modules/issues/8

# Clock in summer, parse a winter date
set_fixed_time(962409600); # 2000-06-30 PDT
is(parsedate('1969/12/31 16:00:00', WHOLE => 1),
    0, 'winter date parsed when clock is in summer');
restore_time();

# Clock in winter, parse a summer date
set_fixed_time(946684800); # 2000-01-01 PST
is(parsedate('2000/07/04 12:00:00', WHOLE => 1),
    962737200, 'summer date parsed when clock is in winter');
restore_time();

# Clock and parsed date in the same DST state
set_fixed_time(962409600); # 2000-06-30 PDT
is(parsedate('2000/07/04 12:00:00', WHOLE => 1),
    962737200, 'summer date parsed when clock is in summer');
restore_time();

set_fixed_time(946684800); # 2000-01-01 PST
is(parsedate('1969/12/31 16:00:00', WHOLE => 1),
    0, 'winter date parsed when clock is in winter');
restore_time();

done_testing();
