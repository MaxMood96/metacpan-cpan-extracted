#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use slot qw(watched_slot);

my @events;

# Test basic watcher
slot::watch('watched_slot', sub {
    my ($name, $value) = @_;
    push @events, { name => $name, value => $value };
});

watched_slot(1);
is(scalar @events, 1, 'watcher fired on set');
is($events[0]{name}, 'watched_slot', 'watcher received slot name');
is($events[0]{value}, 1, 'watcher received new value');

watched_slot(2);
is(scalar @events, 2, 'watcher fires on each set');

# Test more sets
watched_slot(3);
is(scalar @events, 3, 'watcher fires on third set');

watched_slot(4);
is(scalar @events, 4, 'watcher fires on fourth set');

# Test unwatch
@events = ();
slot::unwatch('watched_slot');
watched_slot(99);
is(scalar @events, 0, 'unwatch removes all watchers');

done_testing();
