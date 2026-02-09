use strict;
use warnings;

use Test::More;

use_ok('Linux::Event::Clock') or BAIL_OUT("Cannot load Linux::Event::Clock");

my $c = Linux::Event::Clock->new;
ok($c, 'constructed');

my $g0 = $c->generation;
ok($g0 >= 1, 'generation primed by new()');

my $n0 = $c->now_ns;
ok($n0 > 0, 'now_ns > 0');

my $t1 = $c->tick;
my $g1 = $c->generation;
ok($g1 == $g0 + 1, 'generation increments');
ok($t1 == $c->now_ns, 'tick returns now_ns');

done_testing;
