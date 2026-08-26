use strict;
use warnings;
use Test::More;

use_ok('Alien::TDLib') or BAIL_OUT('cannot load Alien::TDLib');
isa_ok('Alien::TDLib', 'Alien::Base');
can_ok('Alien::TDLib', qw(cflags libs install_type version commit));

done_testing;
