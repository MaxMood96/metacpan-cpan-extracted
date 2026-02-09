use strict;
use warnings;
use Test::More;

plan skip_all => "Linux only" unless $^O eq 'linux';

use_ok('Linux::Event::Timer');

done_testing;
