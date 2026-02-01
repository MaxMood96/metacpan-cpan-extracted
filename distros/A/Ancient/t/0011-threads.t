#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Config;

# Skip if threads not available
plan skip_all => 'threads not available'
    unless $Config{useithreads};

eval { require threads; require threads::shared };
plan skip_all => "threads/threads::shared not available: $@" if $@;

use_ok('slot');

# Slots provide mutex-protected access to values.
# For true cross-thread sharing, store threads::shared data in slots.

# Test 1: Basic slot operations work in threads
{
    package BasicThread;
    use slot qw(counter);
    counter(0);
}

is(BasicThread::counter(), 0, 'initial value');

my $thr1 = threads->create(sub {
    BasicThread::counter(42);
    return BasicThread::counter();
});

my $result = $thr1->join();
is($result, 42, 'thread can get/set slots');

# Test 2: threads::shared data in slots - the recommended pattern
{
    package SharedSlot;
    use slot qw(shared_data);

    my %hash :shared;
    $hash{value} = 100;
    shared_data(\%hash);
}

is(SharedSlot::shared_data()->{value}, 100, 'shared hash initial value');

my $thr2 = threads->create(sub {
    my $data = SharedSlot::shared_data();
    $data->{value} = 200;
    $data->{from_thread} = 1;
    return $data->{value};
});

my $thread_result = $thr2->join();
is($thread_result, 200, 'thread modified shared data');
is(SharedSlot::shared_data()->{value}, 200, 'main thread sees shared modification');
is(SharedSlot::shared_data()->{from_thread}, 1, 'main thread sees new key from thread');

# Test 3: Shared scalar
{
    package SharedScalar;
    use slot qw(shared_counter);

    my $counter :shared = 0;
    shared_counter(\$counter);
}

my @threads;
for my $i (1..5) {
    push @threads, threads->create(sub {
        my $ref = SharedScalar::shared_counter();
        lock($$ref);
        $$ref += 10;
        return $$ref;
    });
}

$_->join() for @threads;
is(${SharedScalar::shared_counter()}, 50, 'shared scalar incremented by all threads');

# Test 4: Shared array
{
    package SharedArray;
    use slot qw(shared_list);

    my @list :shared;
    shared_list(\@list);
}

my @arr_threads;
for my $i (1..3) {
    push @arr_threads, threads->create(sub {
        my $arr = SharedArray::shared_list();
        lock(@$arr);
        push @$arr, $i;
        return scalar @$arr;
    }, $i);
}

$_->join() for @arr_threads;
my @final = sort @{SharedArray::shared_list()};
is_deeply(\@final, [1, 2, 3], 'shared array populated by threads');

done_testing;
