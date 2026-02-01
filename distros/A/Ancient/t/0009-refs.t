#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('slot');

# Test array ref storage
{
    package ArrayTest;
    use slot qw(items);

    items([1, 2, 3]);
    main::is_deeply(items(), [1, 2, 3], 'array ref storage');

    push @{items()}, 4;
    main::is_deeply(items(), [1, 2, 3, 4], 'array ref modification');

    items([]);
    main::is_deeply(items(), [], 'replace with empty array');
}

# Test hash ref storage
{
    package HashTest;
    use slot qw(config);

    config({ name => 'test', count => 0 });
    main::is_deeply(config(), { name => 'test', count => 0 }, 'hash ref storage');

    config()->{count}++;
    main::is(config()->{count}, 1, 'hash ref modification');

    config()->{new_key} = 'value';
    main::is(config()->{new_key}, 'value', 'hash ref add key');
}

# Test code ref storage
{
    package CodeTest;
    use slot qw(callback);

    my $called = 0;
    callback(sub { $called++ });
    main::is(ref(callback()), 'CODE', 'code ref storage');

    callback()->();
    main::is($called, 1, 'code ref execution');

    callback()->();
    main::is($called, 2, 'code ref multiple execution');
}

# Test nested refs
{
    package NestedTest;
    use slot qw(data);

    data({
        list => [1, 2, 3],
        meta => { type => 'test' },
        handler => sub { return 'ok' }
    });

    main::is_deeply(data()->{list}, [1, 2, 3], 'nested array');
    main::is(data()->{meta}{type}, 'test', 'nested hash');
    main::is(data()->{handler}->(), 'ok', 'nested code');
}

# Test ref with watchers
{
    package WatchedRef;
    use slot qw(watched);

    my @events;
    slot::watch('watched', sub {
        my ($name, $val) = @_;
        push @events, ref($val) || 'SCALAR';
    });

    watched([1,2,3]);
    watched({a => 1});
    watched(sub {});
    watched(42);

    main::is_deeply(\@events, ['ARRAY', 'HASH', 'CODE', 'SCALAR'], 'watchers see ref types');
}

done_testing;
