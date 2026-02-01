#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('slot');

# Basic get/set
{
    package Config;
    use slot qw(debug app_name);
    debug(1);
    app_name("MyApp");
}

is(Config::debug(), 1, 'getter');
is(Config::app_name(), "MyApp", 'getter string');

Config::debug(0);
is(Config::debug(), 0, 'setter');

# Cross-package sharing
{
    package ServiceA;
    use slot qw(counter);
    counter(10);
}

{
    package ServiceB;
    use slot qw(counter);
    main::is(counter(), 10, 'same slot shared');
    counter(20);
}

is(ServiceA::counter(), 20, 'cross-package modification');

# Watchers
{
    package Events;
    use slot qw(temp);
    use Test::More;

    my @events;
    slot::watch('temp', sub {
        my ($name, $val) = @_;
        push @events, $val;
    });

    temp(72);
    temp(75);
    temp(80);

    is_deeply(\@events, [72, 75, 80], 'watchers fire');

    slot::unwatch('temp');
    @events = ();
    temp(99);
    is(scalar(@events), 0, 'unwatch works');
}

# Dynamic access
{
    is(slot::get('counter'), 20, 'slot::get');
    slot::set('counter', 999);
    is(ServiceA::counter(), 999, 'slot::set');
}

# Introspection
{
    my @all = sort(slot::slots());
    ok(grep({ $_ eq 'counter' } @all), 'slots() works');
}

done_testing;
