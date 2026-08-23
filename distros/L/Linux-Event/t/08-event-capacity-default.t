use v5.36;
use Test::More;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
is($loop->event_capacity, 8192, 'default event capacity is 8192');

$loop->set_event_capacity(1024);
is($loop->event_capacity, 1024, 'event capacity override still works');

done_testing;
