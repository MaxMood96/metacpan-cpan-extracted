use strict;
use warnings;

use Test::More;

use Flat::Profile;

ok(Flat::Profile->can('new'),         'Flat::Profile->new exists');
ok(Flat::Profile->can('profile_file'), 'Flat::Profile->profile_file exists');
ok(Flat::Profile->can('iter_rows'),    'Flat::Profile->iter_rows exists');

my $profiler = Flat::Profile->new();
isa_ok($profiler, 'Flat::Profile', 'new() returns a Flat::Profile object');

done_testing;
