use Test::More;
use doubly;

ok(my $linked_list = doubly->new());

ok($linked_list->insert_at_end({ a => 1}));
ok($linked_list = $linked_list->insert_at_end({ b => 2 }));
ok($linked_list->insert_at_end({ c => 3 }));

ok($linked_list = $linked_list->start);

is($linked_list->data->{a}, 1);
is($linked_list->next->data->{b}, 2);
is($linked_list->next->next->data->{c}, 3);

done_testing();
