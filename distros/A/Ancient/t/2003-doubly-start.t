use Test::More;
use doubly;

ok(my $linked_list = doubly->new());

ok($linked_list->insert_at_start(1));
ok($linked_list = $linked_list->insert_at_end(2));
ok($linked_list->insert_after(3));

ok($linked_list = $linked_list->start);

is($linked_list->is_start, 1);

done_testing();
