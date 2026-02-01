use Test::More;

use doubly;

my $list = doubly->new(10);

ok($list->add($list->remove));

is($list->data, 10);

done_testing;
