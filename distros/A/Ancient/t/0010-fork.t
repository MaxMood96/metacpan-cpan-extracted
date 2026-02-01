#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Skip if fork not available
plan skip_all => 'fork not available' unless $^O ne 'MSWin32';

use_ok('slot');

{
    package ForkTest;
    use slot qw(shared_val);
    shared_val(100);
}

is(ForkTest::shared_val(), 100, 'initial value set');

my $pid = fork();
if (!defined $pid) {
    die "fork failed: $!";
}

if ($pid == 0) {
    # Child process
    # Should see parent's value (copy-on-write)
    my $child_sees = ForkTest::shared_val();

    # Modify in child
    ForkTest::shared_val(200);
    my $child_modified = ForkTest::shared_val();

    # Exit with status indicating results
    # 0 = both correct, 1 = initial wrong, 2 = modified wrong
    my $status = 0;
    $status = 1 if $child_sees != 100;
    $status = 2 if $child_modified != 200;
    exit($status);
} else {
    # Parent process
    waitpid($pid, 0);
    my $child_status = $? >> 8;

    is($child_status, 0, 'child saw correct values');

    # Parent should still see original value (child's change is isolated)
    is(ForkTest::shared_val(), 100, 'parent value unchanged after child modification');
}

# Test watchers across fork
{
    package WatchFork;
    use slot qw(watched);
    watched(0);

    my @parent_events;
    slot::watch('watched', sub { push @parent_events, $_[1] });

    my $pid = fork();
    if ($pid == 0) {
        # Child - this should fire child's copy of watcher
        watched(999);
        exit(0);
    } else {
        waitpid($pid, 0);

        # Parent watchers should NOT have fired from child's change
        watched(1);
        main::is_deeply(\@parent_events, [1], 'parent watcher only sees parent changes');
    }
}

done_testing;
