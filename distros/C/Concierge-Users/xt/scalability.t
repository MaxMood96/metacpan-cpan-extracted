#!/usr/bin/env perl
# Test: Scalability - Performance with larger datasets
# This file tests Users.pm with larger numbers of records (100, 500, 1000)
# It can be excluded from the test suite if desired

use v5.36;
use Test2::V0;
use File::Temp qw/ tempdir /;
use Time::HiRes qw( time );

use Concierge::Users;

# Test dataset sizes
my @DATASET_SIZES = (100, 500, 1000);

# Performance thresholds (in seconds) - adjust based on expectations
my %THRESHOLDS = (
    '100'   => { create => 5,  read => 1,  update => 5, delete => 5, list => 1 },
    '500'   => { create => 20, read => 3,  update => 20, delete => 20, list => 3 },
    '1000'  => { create => 45, read => 5,  update => 45, delete => 45, list => 5 },
);

# ==============================================================================
# Helper Functions
# ==============================================================================

sub setup_test_env {
    my ($backend, $format) = @_;

    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => $backend,
    };

    # Add file_format for file backend
    $config->{file_format} = $format if $backend eq 'file' && $format;

    my $setup_result = Concierge::Users->setup($config);
    die "Setup failed: $setup_result->{message}" unless $setup_result->{success};

    my $users = Concierge::Users->new($setup_result->{config_file});

    # Enable skip_validation flag for faster bulk operations
    $users->{skip_validation} = 1;

    return ($users, $storage_dir);
}

sub generate_test_users {
    my ($count, $start_id) = @_;

    $start_id ||= 1;
    my @users;

    for my $i ($start_id .. $start_id + $count - 1) {
        my $num = sprintf("%04d", $i);
        push @users, {
            user_id   => "user_$num",
            moniker   => "Moniker$num",
        };
    }

    return @users;
}

sub timed_operation {
    my ($code, $desc) = @_;

    my $start = time();
    my $result = $code->();
    my $elapsed = time() - $start;

    return ($result, $elapsed);
}

# ==============================================================================
# Test: Database Backend Scalability
# ==============================================================================

subtest 'Database: Scalability with larger datasets' => sub {
    for my $size (@DATASET_SIZES) {
        subtest "Database: Create $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('database');

            my @test_users = generate_test_users($size);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $user_data (@test_users) {
                        push @$results, $users->register_user($user_data);
                    }
                    return $results;
                },
                "Create $size users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $size, "All $size users created");

            diag sprintf("Database: Created %d users in %.3f seconds (%.2f users/sec)",
                $size, $elapsed, $size / $elapsed);

            my $threshold = $THRESHOLDS{$size}{create};
            ok($elapsed < $threshold, "Create time ($elapsed sec) under threshold ($threshold sec)")
                or diag "WARNING: Create operation slower than expected";

            # Verify all users are accessible
            my $list = $users->list_users();
            is($list->{total_count}, $size, "All $size users are in the database");
        };

        subtest "Database: Read operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('database');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Test individual reads
            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    # Sample 10 random users
                    for my $i (1..10) {
                        my $random_id = int(rand($size)) + 1;
                        my $user_id = sprintf("user_%04d", $random_id);
                        push @$results, $users->get_user($user_id);
                    }
                    return $results;
                },
                "Read 10 random users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, 10, "Successfully read 10 users");

            diag sprintf("Database: Read 10 individual users in %.3f seconds (%.3f sec/read)",
                $elapsed, $elapsed / 10);

            # Test list operation
            my ($list_result, $list_elapsed) = timed_operation(
                sub { $users->list_users() },
                "List all users"
            );

            ok($list_result->{success}, "List operation succeeded");
            is($list_result->{total_count}, $size, "List returned $size users");

            diag sprintf("Database: Listed all %d users in %.3f seconds",
                $size, $list_elapsed);

            my $threshold = $THRESHOLDS{$size}{read};
            ok($list_elapsed < $threshold, "List time ($list_elapsed sec) under threshold ($threshold sec)")
                or diag "WARNING: List operation slower than expected";
        };

        subtest "Database: Update operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('database');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Update a subset (10% of users)
            my $update_count = int($size * 0.1);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..$update_count) {
                        my $user_id = sprintf("user_%04d", $i);
                        my $new_moniker = "Updated" . sprintf("%04d", $i);
                        push @$results, $users->update_user($user_id, {
                            moniker => $new_moniker
                        });
                    }
                    return $results;
                },
                "Update $update_count users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $update_count, "Successfully updated $update_count users");

            diag sprintf("Database: Updated %d users in %.3f seconds (%.2f users/sec)",
                $update_count, $elapsed, $update_count / $elapsed);

            my $threshold = $THRESHOLDS{$size}{update};
            ok($elapsed < $threshold, "Update time ($elapsed sec) under threshold ($threshold sec)")
                or diag "WARNING: Update operation slower than expected";

            # Verify updates persisted
            my $verify = $users->get_user('user_0001');
            is($verify->{user}{moniker}, 'Updated0001', 'Update persisted correctly');
        };

        subtest "Database: Filter with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('database');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Test filtering by user_id
            my ($filtered, $filter_elapsed) = timed_operation(
                sub { $users->list_users('user_id=user_0050') },
                "Filter users"
            );

            ok($filtered->{success}, "Filter operation succeeded");
            diag sprintf("Database: Filtered %d users in %.3f seconds",
                $size, $filter_elapsed);

            # Test pattern matching on moniker
            my ($pattern, $pattern_elapsed) = timed_operation(
                sub { $users->list_users('moniker:Moniker0') },
                "Pattern match users"
            );

            ok($pattern->{success}, "Pattern match succeeded");

            # Note: list_users returns user_ids, so pattern match should find matching users
            diag sprintf("Database: Pattern matched on %d users in %.3f seconds",
                $size, $pattern_elapsed);
        };

        subtest "Database: Delete operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('database');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Delete a subset (10% of users)
            my $delete_count = int($size * 0.1);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..$delete_count) {
                        my $user_id = sprintf("user_%04d", $i);
                        push @$results, $users->delete_user($user_id);
                    }
                    return $results;
                },
                "Delete $delete_count users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $delete_count, "Successfully deleted $delete_count users");

            diag sprintf("Database: Deleted %d users in %.3f seconds (%.2f users/sec)",
                $delete_count, $elapsed, $delete_count / $elapsed);

            my $threshold = $THRESHOLDS{$size}{delete};
            ok($elapsed < $threshold, "Delete time ($elapsed sec) under threshold ($threshold sec)")
                or diag "WARNING: Delete operation slower than expected";

            # Verify count decreased
            my $list = $users->list_users();
            is($list->{total_count}, $size - $delete_count, "User count decreased correctly");
        };
    }
};

# ==============================================================================
# Test: File Backend Scalability (TSV)
# ==============================================================================

subtest 'File (TSV): Scalability with larger datasets' => sub {
    for my $size (@DATASET_SIZES) {
        subtest "File (TSV): Create $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('file', 'tsv');

            my @test_users = generate_test_users($size);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $user_data (@test_users) {
                        push @$results, $users->register_user($user_data);
                    }
                    return $results;
                },
                "Create $size users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $size, "All $size users created");

            diag sprintf("File (TSV): Created %d users in %.3f seconds (%.2f users/sec)",
                $size, $elapsed, $size / $elapsed);

            my $threshold = $THRESHOLDS{$size}{create};
            ok($elapsed < $threshold * 1.5, "Create time ($elapsed sec) under threshold (" . ($threshold * 1.5) . " sec)")
                or diag "WARNING: Create operation slower than expected";

            # Verify file exists
            ok(-f "$storage_dir/users.tsv", "TSV file exists");
        };

        subtest "File (TSV): Read operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('file', 'tsv');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Test individual reads
            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..10) {
                        my $random_id = int(rand($size)) + 1;
                        my $user_id = sprintf("user_%04d", $random_id);
                        push @$results, $users->get_user($user_id);
                    }
                    return $results;
                },
                "Read 10 random users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, 10, "Successfully read 10 users");

            diag sprintf("File (TSV): Read 10 individual users in %.3f seconds (%.3f sec/read)",
                $elapsed, $elapsed / 10);

            # Test list operation
            my ($list_result, $list_elapsed) = timed_operation(
                sub { $users->list_users() },
                "List all users"
            );

            ok($list_result->{success}, "List operation succeeded");
            is($list_result->{total_count}, $size, "List returned $size users");

            diag sprintf("File (TSV): Listed all %d users in %.3f seconds",
                $size, $list_elapsed);

            my $threshold = $THRESHOLDS{$size}{read};
            ok($list_elapsed < $threshold * 1.5, "List time ($list_elapsed sec) under threshold (" . ($threshold * 1.5) . " sec)")
                or diag "WARNING: List operation slower than expected";
        };

        subtest "File (TSV): Update operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('file', 'tsv');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Update a subset (10% of users)
            my $update_count = int($size * 0.1);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..$update_count) {
                        my $user_id = sprintf("user_%04d", $i);
                        my $new_moniker = "Updated" . sprintf("%04d", $i);
                        push @$results, $users->update_user($user_id, {
                            moniker => $new_moniker
                        });
                    }
                    return $results;
                },
                "Update $update_count users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $update_count, "Successfully updated $update_count users");

            diag sprintf("File (TSV): Updated %d users in %.3f seconds (%.2f users/sec)",
                $update_count, $elapsed, $update_count / $elapsed);

            # Verify updates persisted
            my $verify = $users->get_user('user_0001');
            is($verify->{user}{moniker}, 'Updated0001', 'Update persisted correctly');
        };
    }
};

# ==============================================================================
# Test: File Backend Scalability (CSV)
# ==============================================================================

subtest 'File (CSV): Scalability with larger datasets' => sub {
    for my $size (100, 500) {  # Only test 100 and 500 for CSV to save time
        subtest "File (CSV): Create $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('file', 'csv');

            my @test_users = generate_test_users($size);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $user_data (@test_users) {
                        push @$results, $users->register_user($user_data);
                    }
                    return $results;
                },
                "Create $size users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $size, "All $size users created");

            diag sprintf("File (CSV): Created %d users in %.3f seconds (%.2f users/sec)",
                $size, $elapsed, $size / $elapsed);

            # Verify file exists
            ok(-f "$storage_dir/users.csv", "CSV file exists");
        };
    }
};

# ==============================================================================
# Test: YAML Backend Scalability
# ==============================================================================

subtest 'YAML: Scalability with larger datasets' => sub {
    for my $size (@DATASET_SIZES) {
        subtest "YAML: Create $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('yaml');

            my @test_users = generate_test_users($size);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $user_data (@test_users) {
                        push @$results, $users->register_user($user_data);
                    }
                    return $results;
                },
                "Create $size users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $size, "All $size users created");

            diag sprintf("YAML: Created %d users in %.3f seconds (%.2f users/sec)",
                $size, $elapsed, $size / $elapsed);

            my $threshold = $THRESHOLDS{$size}{create};
            ok($elapsed < $threshold * 2, "Create time ($elapsed sec) under threshold (" . ($threshold * 2) . " sec)")
                or diag "WARNING: Create operation slower than expected";

            # Verify YAML files exist in storage_dir
            ok(-d $storage_dir, "YAML storage directory exists");

            # Count only user YAML files (exclude config files)
            my @yaml_files = glob("$storage_dir/user_*.yaml");
            my $file_count = scalar(@yaml_files);
            is($file_count, $size, "YAML has $size individual user files");
        };

        subtest "YAML: Read operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('yaml');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Test individual reads
            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..10) {
                        my $random_id = int(rand($size)) + 1;
                        my $user_id = sprintf("user_%04d", $random_id);
                        push @$results, $users->get_user($user_id);
                    }
                    return $results;
                },
                "Read 10 random users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, 10, "Successfully read 10 users");

            diag sprintf("YAML: Read 10 individual users in %.3f seconds (%.3f sec/read)",
                $elapsed, $elapsed / 10);

            # Test list operation
            my ($list_result, $list_elapsed) = timed_operation(
                sub { $users->list_users() },
                "List all users"
            );

            ok($list_result->{success}, "List operation succeeded");
            is($list_result->{total_count}, $size, "List returned $size users");

            diag sprintf("YAML: Listed all %d users in %.3f seconds",
                $size, $list_elapsed);

            my $threshold = $THRESHOLDS{$size}{read};
            ok($list_elapsed < $threshold * 2, "List time ($list_elapsed sec) under threshold (" . ($threshold * 2) . " sec)")
                or diag "WARNING: List operation slower than expected";
        };

        subtest "YAML: Update operations with $size users" => sub {
            my ($users, $storage_dir) = setup_test_env('yaml');

            # Create users first
            my @test_users = generate_test_users($size);
            $users->register_user($_) for @test_users;

            # Update a subset (10% of users)
            my $update_count = int($size * 0.1);

            my ($result, $elapsed) = timed_operation(
                sub {
                    my $results = [];
                    for my $i (1..$update_count) {
                        my $user_id = sprintf("user_%04d", $i);
                        my $new_moniker = "Updated" . sprintf("%04d", $i);
                        push @$results, $users->update_user($user_id, {
                            moniker => $new_moniker
                        });
                    }
                    return $results;
                },
                "Update $update_count users"
            );

            my $success_count = grep { $_->{success} } @$result;
            is($success_count, $update_count, "Successfully updated $update_count users");

            diag sprintf("YAML: Updated %d users in %.3f seconds (%.2f users/sec)",
                $update_count, $elapsed, $update_count / $elapsed);

            # Verify updates persisted
            my $verify = $users->get_user('user_0001');
            is($verify->{user}{moniker}, 'Updated0001', 'Update persisted correctly');
        };
    }
};

# ==============================================================================
# Summary and Analysis
# ==============================================================================

subtest 'Scalability Summary' => sub {
    diag "=" x 70;
    diag "SCALABILITY TEST SUMMARY";
    diag "=" x 70;
    diag "";
    diag "Dataset sizes tested: " . join(", ", @DATASET_SIZES);
    diag "";
    diag "Expected performance characteristics:";
    diag "  - Database: Consistent performance across all operations";
    diag "  - File (CSV/TSV): Good for read-heavy workloads";
    diag "  - YAML: Good for individual user operations, file system dependent";
    diag "";
    diag "All backends should handle 1000+ users efficiently";
    diag "For larger deployments (>5000 users), consider Database backend";
    diag "=" x 70;

    # Add a simple pass test so subtest isn't empty
    ok(1, "Scalability tests completed");
};

done_testing();
