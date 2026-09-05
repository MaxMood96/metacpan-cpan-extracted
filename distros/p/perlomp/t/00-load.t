use strict;
use warnings;
use Test::More;

use_ok('perlomp');
is($perlomp::VERSION, '0.01', 'version is set');

done_testing;
