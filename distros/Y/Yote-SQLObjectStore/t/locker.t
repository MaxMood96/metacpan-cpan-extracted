#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use lib './t/lib';
use lib './lib';

use Yote::Locker;
use Yote::SQLObjectStore;

use File::Temp qw/ tempdir /;
use Test::Exception;
use Test::More;
use Time::HiRes qw(time usleep);
use POSIX qw(:sys_wait_h);

# =====================================================================
# Yote::Locker unit tests
# =====================================================================

subtest 'locker basics' => sub {
    my $dir = tempdir( CLEANUP => 1 );
    my $lockfile = "$dir/test.lock";

    # constructor creates lock file and starts locked
    my $locker = Yote::Locker->new( $lockfile );
    ok( -e $lockfile, 'lock file created on disk' );
    ok( $locker->is_locked, 'locker starts locked after construction' );

    # unlock
    $locker->unlock;
    ok( !$locker->is_locked, 'locker reports unlocked after unlock' );

    # lock again
    $locker->lock;
    ok( $locker->is_locked, 'locker reports locked after re-lock' );

    # lock while already locked is a no-op
    my $ret = $locker->lock;
    is( $ret, 1, 'locking while already locked returns 1' );
    ok( $locker->is_locked, 'still locked after double lock' );

    # unlock again
    $locker->unlock;
    ok( !$locker->is_locked, 'unlocked again' );
};

subtest 'locker with pre-existing lock file' => sub {
    my $dir = tempdir( CLEANUP => 1 );
    my $lockfile = "$dir/test.lock";

    # create the lock file first
    open my $fh, '>', $lockfile or die "cannot create lockfile: $!";
    print $fh "PRE-EXISTING";
    close $fh;
    ok( -e $lockfile, 'pre-existing lock file exists' );

    # constructor should still work with a pre-existing file
    my $locker = Yote::Locker->new( $lockfile );
    ok( $locker->is_locked, 'locker locked with pre-existing file' );

    $locker->unlock;
    ok( !$locker->is_locked, 'unlocked with pre-existing file' );
};

subtest 'locker dies on invalid path' => sub {
    throws_ok {
        Yote::Locker->new( '/nonexistent/deeply/nested/path/test.lock' );
    } qr/unable to open lock file|cannot open/i, 'dies when lock file path is invalid';
};

# =====================================================================
# Locker integration with SQLite store
# =====================================================================

sub make_all_tables {
    my $object_store = shift;
    local @INC = qw( ./lib ./t/lib );
    $object_store->make_all_tables( @INC );
}

subtest 'sqlite store creates locker and lock file' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );

    ok( -e "$dir/SQLITE.lock", 'SQLITE.lock file created alongside database' );
    ok( -e "$dir/SQLITE.db",   'SQLITE.db file created' );
    ok( $store->{LOCKER}, 'store has a LOCKER' );
    ok( !$store->{LOCKER}->is_locked, 'locker starts unlocked (released in constructor)' );
};

subtest 'transactions acquire and release lock' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;

    my $locker = $store->{LOCKER};
    ok( !$locker->is_locked, 'unlocked before transaction' );

    # start_transaction should lock
    $store->start_transaction;
    ok( $locker->is_locked, 'locked after start_transaction' );

    # commit should unlock
    $store->commit_transaction;
    ok( !$locker->is_locked, 'unlocked after commit_transaction' );

    # start again, then rollback
    $store->start_transaction;
    ok( $locker->is_locked, 'locked after second start_transaction' );

    $store->rollback_transaction;
    ok( !$locker->is_locked, 'unlocked after rollback_transaction' );
};

subtest 'nested transaction calls do not double-lock' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;

    my $locker = $store->{LOCKER};

    $store->start_transaction;
    ok( $locker->is_locked, 'locked after first start' );

    # second start should be a no-op (already in transaction)
    $store->start_transaction;
    ok( $locker->is_locked, 'still locked after redundant start' );

    # one commit should unlock
    $store->commit_transaction;
    ok( !$locker->is_locked, 'unlocked after single commit' );

    # redundant commit should be a no-op
    $store->commit_transaction;
    ok( !$locker->is_locked, 'still unlocked after redundant commit' );
};

subtest 'save acquires and releases lock' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;

    my $locker = $store->{LOCKER};

    my $root = $store->fetch_root;
    $root->get_val_hash->{color} = 'blue';
    ok( !$locker->is_locked, 'unlocked before save' );

    $store->save;
    ok( !$locker->is_locked, 'unlocked after save completes' );

    # verify the data persisted
    is( $store->fetch_string_path( '/val_hash/color' ), 'blue', 'saved data is retrievable' );
};

subtest 'ensure_path acquires and releases lock' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;

    my $locker = $store->{LOCKER};

    ok( !$locker->is_locked, 'unlocked before ensure_path' );

    $store->ensure_path( '/val_hash/greeting|hello' );

    ok( !$locker->is_locked, 'unlocked after ensure_path' );
    is( $store->fetch_string_path( '/val_hash/greeting' ), 'hello', 'ensure_path data is retrievable' );
};

subtest 'rollback on error still releases lock' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;

    my $locker = $store->{LOCKER};

    # ensure_paths with a bad path should rollback and release the lock
    eval {
        $store->ensure_paths(
            '/val_hash/good|value',
            '/val_hash/oops|nope/this_breaks',
        );
    };
    ok( $@, 'ensure_paths with bad path dies' );
    ok( !$locker->is_locked, 'lock released after failed ensure_paths (rollback)' );

    # the good value should NOT have been committed (transaction rolled back)
    is( $store->fetch_string_path( '/val_hash/good' ), undef, 'rolled-back data is not persisted' );
};

# =====================================================================
# Multi-process locking tests
# =====================================================================

subtest 'multi-process lock exclusion' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;
    $store->save;

    # a file to record ordering of events from parent and child
    my $log_file = "$dir/event_log";

    my $pid = fork();
    if (!defined $pid) {
        die "fork failed: $!";
    }

    if ($pid == 0) {
        # --- CHILD PROCESS ---
        # Open a fresh store connection (new DBH)
        my $child_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
        );
        $child_store->open;

        # Acquire the lock via transaction
        $child_store->start_transaction;

        # Log that child has the lock
        _append_log( $log_file, "child_locked" );

        # Hold the lock for a bit
        usleep( 200_000 ); # 200ms

        my $root = $child_store->fetch_root;
        $root->get_val_hash->{writer} = 'child';
        $child_store->store_obj_data_to_sql( $root->get_val_hash );

        $child_store->commit_transaction;
        _append_log( $log_file, "child_unlocked" );

        exit 0;
    }

    # --- PARENT PROCESS ---
    # Give the child a moment to grab the lock
    usleep( 50_000 ); # 50ms

    # Now the parent tries to start a transaction — should block
    # until the child releases
    my $before = time();
    $store->start_transaction;
    my $after = time();

    _append_log( $log_file, "parent_locked" );

    $store->commit_transaction;
    _append_log( $log_file, "parent_unlocked" );

    # Wait for child to finish
    waitpid( $pid, 0 );
    is( $? >> 8, 0, 'child exited cleanly' );

    # The parent should have been blocked for at least ~100ms
    # (child holds lock for 200ms, parent tries at 50ms)
    my $wait_time = $after - $before;
    ok( $wait_time >= 0.1, "parent waited for child's lock (${wait_time}s >= 0.1s)" );

    # Check that the child wrote first, then parent got the lock
    my @events = _read_log( $log_file );
    is( $events[0], 'child_locked',   'child locked first' );
    is( $events[1], 'child_unlocked', 'child unlocked before parent' );
    is( $events[2], 'parent_locked',  'parent locked after child released' );
};

subtest 'concurrent object creation without errors' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;
    $store->save;

    # Each child creates independent SomeThing objects (each gets its own
    # row in the table, no shared container delete-reinsert issues).
    my $num_children = 4;
    my $objs_per_child = 5;

    my @pids;
    for my $i (1..$num_children) {
        my $pid = fork();
        die "fork failed: $!" unless defined $pid;

        if ($pid == 0) {
            my $child_store = Yote::SQLObjectStore->new( 'SQLite',
                BASE_DIRECTORY => $dir,
            );
            $child_store->open;

            for my $j (1..$objs_per_child) {
                my $obj = $child_store->new_obj(
                    'SQLite::SomeThing',
                    name    => "child_${i}_obj_${j}",
                    tagline => "proc_$i",
                );
                $child_store->save( $obj );
            }
            exit 0;
        }
        push @pids, $pid;
    }

    # Wait for all children
    for my $pid (@pids) {
        waitpid( $pid, 0 );
        is( $? >> 8, 0, "child $pid exited cleanly" );
    }

    # Reopen and verify all objects made it to the database
    my $verify_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    $verify_store->open;

    my $total_expected = $num_children * $objs_per_child;
    my $found = 0;
    for my $i (1..$num_children) {
        for my $j (1..$objs_per_child) {
            my $name = "child_${i}_obj_${j}";
            my $obj = $verify_store->find_by( 'SQLite::SomeThing', 'name', $name );
            if ($obj) {
                $found++;
                is( $obj->get_tagline, "proc_$i", "object '$name' has correct tagline" );
            } else {
                fail( "object '$name' not found in store" );
            }
        }
    }
    is( $found, $total_expected,
        "all $total_expected objects created by concurrent processes are present" );
};

subtest 'concurrent transactions are serialized' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $store );
    $store->open;
    $store->save;

    my $log_file = "$dir/order_log";
    my $num_children = 3;

    # Each child acquires the lock, writes its id, holds the lock briefly,
    # then releases. We verify no two children held the lock at the same time.
    my @pids;
    for my $i (1..$num_children) {
        my $pid = fork();
        die "fork failed: $!" unless defined $pid;

        if ($pid == 0) {
            my $child_store = Yote::SQLObjectStore->new( 'SQLite',
                BASE_DIRECTORY => $dir,
            );
            $child_store->open;

            $child_store->start_transaction;
            _append_log( $log_file, "enter_$i" );
            usleep( 50_000 ); # hold lock for 50ms
            _append_log( $log_file, "exit_$i" );
            $child_store->commit_transaction;

            exit 0;
        }
        push @pids, $pid;
    }

    for my $pid (@pids) {
        waitpid( $pid, 0 );
        is( $? >> 8, 0, "child $pid exited cleanly" );
    }

    # Verify the log shows strictly alternating enter/exit (no overlaps)
    my @events = _read_log( $log_file );
    is( scalar @events, $num_children * 2,
        "expected " . ($num_children * 2) . " events in log" );

    my $overlaps = 0;
    my $in_lock = 0;
    for my $event (@events) {
        if ($event =~ /^enter_/) {
            $overlaps++ if $in_lock;
            $in_lock = 1;
        } elsif ($event =~ /^exit_/) {
            $in_lock = 0;
        }
    }
    is( $overlaps, 0, 'no overlapping lock holders (transactions were serialized)' );
};

done_testing;

# =====================================================================
# Helper subs for multi-process log file
# =====================================================================

sub _append_log {
    my ($file, $msg) = @_;
    open my $fh, '>>', $file or die "cannot append to $file: $!";
    flock( $fh, 2 ); # LOCK_EX
    print $fh "$msg\n";
    flock( $fh, 8 ); # LOCK_UN
    close $fh;
}

sub _read_log {
    my ($file) = @_;
    open my $fh, '<', $file or return ();
    my @lines;
    while (<$fh>) {
        chomp;
        push @lines, $_ if $_;
    }
    close $fh;
    return @lines;
}
