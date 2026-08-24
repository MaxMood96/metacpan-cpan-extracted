#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

use_ok('Punk::Sqitch');
ok(Punk::Sqitch->can('target_for'), 'target_for');
ok(Punk::Sqitch->can('run'),        'run');
diag("Punk::Sqitch $Punk::Sqitch::VERSION, Perl $], $^X");
done_testing();
