use Test::More;
use doubly;

ok(my $linked_list = doubly->new());

ok($linked_list->insert_before({ c => 3 })); # first always get set
my $start = $linked_list->start;
ok($linked_list = $linked_list->insert_before({ b => 2 }));
ok($linked_list->insert_before({ a => 1 }));
is($start->data->{c}, 3);
ok($linked_list = $linked_list->start);

is($linked_list->data->{a}, 1);
is($linked_list->next->data->{b}, 2);
is($linked_list->next->next->data->{c}, 3);

done_testing();
