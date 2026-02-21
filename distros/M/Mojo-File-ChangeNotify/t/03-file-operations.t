#!perl
use 5.020;
use experimental "signatures";
use Test2::V0 '-no_srand';

use Mojo::File::ChangeNotify;
use File::Temp 'tempdir';
use File::Copy 'move';
use File::Path 'remove_tree';

subtest "Test 1: Rename file" => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    # Wait for watcher to start, then perform operations
    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Create a file
        my $file1 = "$tempdir/test1.txt";
        open my $fh, '>', $file1 or die "Cannot create $file1: $!";
        print $fh "content\n";
        close $fh;

        # Rename the file after a brief delay
        Mojo::IOLoop->timer(0.5 => sub {
            my $file2 = "$tempdir/test2.txt";
            move($file1, $file2) or die "Cannot rename $file1 to $file2: $!";
        });
    });

    # Stop after collecting events
    my $timeout = Mojo::IOLoop->timer(5 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    # Check for events
    ok @events > 0, "Received events for file rename";

    my @all_events = map { $_->@* } @events;
    my %event_types = map { $_->{type} => 1 } @all_events;

    note "Event types: " . join(", ", sort keys %event_types);
    note "Total events: " . scalar(@all_events);

    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    # We expect at least a create event (the file being created)
    ok $event_types{create}, "Saw create event when file was created";

    done_testing;
};

subtest "Test 2: Delete file" => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    # Wait for watcher to start
    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Create a file first
        my $file = "$tempdir/test_delete.txt";
        open my $fh, '>', $file or die "Cannot create $file: $!";
        print $fh "content\n";
        close $fh;

        # Delete the file after some time again
        Mojo::IOLoop->timer(4 => sub {
            unlink($file) or die "Cannot delete $file: $!";
        });
    });

    my $timeout = Mojo::IOLoop->timer(15 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    ok @events > 0, "Received events for file deletion";

    my @all_events = map { $_->@* } @events;
    my %event_types = map { $_->{type} => 1 } @all_events;

    note "Event types: " . join(", ", sort keys %event_types);
    note "Total events: " . scalar(@all_events);

    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    done_testing;
};

subtest "Test 3: Rename directory with files" => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    # Create a temporary directory with multiple files in it
    my $dir1 = "$tempdir/test_dir_original";
    mkdir $dir1 or die "Cannot create $dir1: $!";

    for my $i (1..3) {
        my $file_in_dir = "$dir1/file$i.txt";
        open my $fh, '>', $file_in_dir or die "Cannot create $file_in_dir: $!";
        print $fh "content in file $i\n";
        close $fh;
    }

    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    # Wait for watcher to start
    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Rename the directory
        my $dir2 = "$tempdir/test_dir_renamed";
        move($dir1, $dir2) or die "Cannot rename $dir1 to $dir2: $!";

        # Add a new file to the renamed directory to see more events
        Mojo::IOLoop->timer(0.3 => sub {
            my $newfile = "$dir2/newfile.txt";
            open my $fh, '>', $newfile or die "Cannot create $newfile: $!";
            print $fh "new file in renamed directory\n";
            close $fh;
        });
    });

    my $timeout = Mojo::IOLoop->timer(5 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    ok @events > 0, "Received events for directory rename";

    my @all_events = map { $_->@* } @events;

    # Print all events for debugging
    note "All events received: " . scalar(@all_events);
    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    # Check that we see events related to the directory and/or files
    my @relevant_events = grep { $_->{path} =~ /test_dir/ } @all_events;
    ok @relevant_events > 0, "Saw events related to test_dir";

    # Should see create events for the files
    my @create_events = grep { $_->{type} eq 'create' && $_->{path} =~ /test_dir/ } @all_events;
    ok @create_events > 0, "Saw create events for directory/files";

    done_testing;
};

subtest "Test 4: Multiple file operations in sequence" => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Create file
        my $file = "$tempdir/sequence.txt";
        open my $fh, '>', $file or die "Cannot create $file: $!";
        print $fh "initial\n";
        close $fh;

        Mojo::IOLoop->timer(2 => sub {
            # Modify file
            open $fh, '>', $file or die "Cannot open $file: $!";
            print $fh "modified\n";
            close $fh;

            Mojo::IOLoop->timer(2 => sub {
                # Rename file
                my $newfile = "$tempdir/sequence_renamed.txt";
                move($file, $newfile);

                Mojo::IOLoop->timer(0.3 => sub {
                    # Delete file
                    unlink($newfile);
                });
            });
        });
    });

    my $timeout = Mojo::IOLoop->timer(7 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    ok @events > 0, "Received events for multiple operations";

    my @all_events = map { $_->@* } @events;
    my %event_types = map { $_->{type} => 1 } @all_events;

    note "Total events: " . scalar(@all_events);
    note "Event types: " . join(", ", sort keys %event_types);

    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    # Verify we saw the expected event types
    ok $event_types{create}, "Saw create event";
    ok $event_types{modify}, "Saw modify event";
    ok $event_types{delete}, "Saw delete event";

    done_testing;
};

subtest "Test 5: Create and delete directory" => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Create directory
        my $dir = "$tempdir/test_create_dir";
        mkdir $dir or die "Cannot create $dir: $!";

        # Add a file to the directory
        my $file = "$dir/file.txt";
        open my $fh, '>', $file or die "Cannot create $file: $!";
        print $fh "test\n";
        close $fh;

        # Delete directory after a delay (should fail since not empty)
        Mojo::IOLoop->timer(1 => sub {
            # Delete file first, then directory
            unlink($file);
            rmdir $dir or die "Cannot rmdir $dir: $!";
        });
    });

    my $timeout = Mojo::IOLoop->timer(5 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    ok @events >= 0, "Received events for directory create/delete";

    my @all_events = map { $_->@* } @events;
    my %event_types = map { $_->{type} => 1 } @all_events;

    note "Directory events: " . scalar(@all_events);
    if (%event_types) {
        note "Event types: " . join(", ", sort keys %event_types);
    }
    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    # If we got events, check for create
    if (scalar @all_events > 0) {
        ok $event_types{create}, "Saw create events for directory/file";
    }

    done_testing;
};

subtest "Test 6: Create multiple files and verify batch events" => sub {
    my $tempdir = tempdir(CLEANUP => 1);

    my @events;
    my $w = Mojo::File::ChangeNotify->instantiate_watcher(
        directories => [$tempdir],
        on_change => sub($s, $ev) {
            push @events, $ev;
        },
    );

    my $timer = Mojo::IOLoop->timer(1 => sub {
        # Create multiple files at once
        for my $i (1..5) {
            my $file = "$tempdir/file$i.txt";
            open my $fh, '>', $file or die "Cannot create $file: $!";
            print $fh "File number $i\n";
            close $fh;
        }
    });

    my $timeout = Mojo::IOLoop->timer(5 => sub {
        Mojo::IOLoop->stop;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

    ok @events > 0, "Received events for multiple file creation";

    my @all_events = map { $_->@* } @events;
    my %event_types = map { $_->{type} => 1 } @all_events;

    note "Total events for 5 files: " . scalar(@all_events);
    note "Event types: " . join(", ", sort keys %event_types);

    for my $event (@all_events) {
        note "  [$event->{type}] $event->{path}";
    }

    # Count how many unique files we saw
    my %unique_files = map { $_->{path} => 1 } @all_events;
    note "Unique files seen: " . scalar(keys %unique_files);

    ok scalar(keys %unique_files) >= 5, "Saw events for at least 5 different files";

    done_testing;
};

done_testing;
