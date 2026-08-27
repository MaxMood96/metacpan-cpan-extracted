use strict;
use warnings;
use Test::More;

use_ok('EV::Telegram::TDLib') or BAIL_OUT('cannot load');
can_ok('EV::Telegram::TDLib', qw(new send execute close login));
is(EV::Telegram::TDLib->CLONE_SKIP, 1, 'CLONE_SKIP is 1');

done_testing;
