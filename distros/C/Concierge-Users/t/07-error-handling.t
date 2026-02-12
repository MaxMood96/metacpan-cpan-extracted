#!/usr/bin/env perl
# Test: Error handling and edge cases

use v5.36;
use Test2::V0;
use Test2::Tools::Exception qw/ dies lives /;
use File::Temp qw/ tempdir /;
use File::Path qw/ remove_tree /;
use Concierge::Users;

# Helper to setup test environment
sub setup_test_env {
    my $backend = shift;

    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => $backend,
        include_standard_fields => [qw/ email /],
    };

    my $setup_result = Concierge::Users->setup($config);
    die "Setup failed: $setup_result->{message}" unless $setup_result->{success};

    my $users = Concierge::Users->new($setup_result->{config_file});
    $users->{skip_validation} = 1;

    return ($users, $storage_dir, $setup_result->{config_file});
}

# ==============================================================================
# Test Group 1: Setup Error Conditions
# ==============================================================================
subtest 'Setup error conditions' => sub {
    # Test 1: Missing storage_dir - fatal error, should croak
    like(
        dies { Concierge::Users->setup({ backend => 'database' }) },
        qr/storage_dir/,
        'Croaks with storage_dir error when storage_dir missing'
    );

    # Test 2: Missing backend - fatal error, should croak
    like(
        dies { Concierge::Users->setup({ storage_dir => '/tmp/test' }) },
        qr/backend/,
        'Croaks with backend error when backend missing'
    );

    # Test 3: Invalid backend - fatal error, should croak
    like(
        dies {
            Concierge::Users->setup({
                storage_dir => '/tmp/test',
                backend => 'invalid_backend'
            })
        },
        qr/Invalid backend|backend/,
        'Croaks with error for invalid backend'
    );

    # Test 4: Invalid file format - backend returns error hashref
    my $storage_dir = tempdir(CLEANUP => 1);
    my $result4 = Concierge::Users->setup({
        storage_dir => $storage_dir,
        backend => 'file',
        file_format => 'xml'
    });
    ok(!$result4->{success}, 'Fails with invalid file format');
    like($result4->{message}, qr/file_format|invalid/, 'Error mentions file_format');

    # Test 5: Hash reference required
    like(
        dies { Concierge::Users->setup('invalid') },
        qr/hash reference/i,
        'Croaks with error for non-hash config'
    );
};

# ==============================================================================
# Test Group 2: Constructor Error Conditions
# ==============================================================================
subtest 'Constructor error conditions' => sub {
    # Test 1: Missing config file
    like(
        dies { Concierge::Users->new() },
        qr/Usage:/,
        'Dies with usage hint when no config file'
    );

    # Test 2: Non-existent config file
    like(
        dies { Concierge::Users->new('/nonexistent/file.json') },
        qr/call.*setup.*first/i,
        'Dies with helpful message for missing config file'
    );

    # Test 3: Invalid JSON in config file
    my $storage_dir = tempdir(CLEANUP => 1);
    my $bad_config = "$storage_dir/bad-config.json";

    open my $fh, '>', $bad_config or die "Cannot create test file: $!";
    print $fh "{ invalid json }";
    close $fh;

    like(
        dies { Concierge::Users->new($bad_config) },
        qr/Failed to parse/,
        'Dies with parse error for invalid JSON'
    );

    # Test 4: Config missing required keys
    my $incomplete_config = "$storage_dir/incomplete-config.json";
    open $fh, '>', $incomplete_config or die "Cannot create test file: $!";
    print $fh qq/{"version": "1.0"}/;  # Missing backend_module and fields
    close $fh;

    like(
        dies { Concierge::Users->new($incomplete_config) },
        qr/Invalid config file/,
        'Dies with error for incomplete config'
    );
};

# ==============================================================================
# Test Group 3: Register User Error Conditions
# ==============================================================================
subtest 'Register user error conditions' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: Missing user_data
    my $result1 = $users->register_user();
    ok(!$result1->{success}, 'Fails without user_data');
    like($result1->{message}, qr/hash reference/, 'Error mentions data type');

    # Test 2: Invalid user_data type
    my $result2 = $users->register_user('invalid');
    ok(!$result2->{success}, 'Fails with non-hash data');

    # Test 3: Duplicate user_id
    $users->register_user({
        user_id => 'duplicate',
        moniker => 'First',
    });

    my $result3 = $users->register_user({
        user_id => 'duplicate',
        moniker => 'Second',
    });
    ok(!$result3->{success}, 'Fails with duplicate user_id');
    like($result3->{message}, qr/already exists/, 'Error mentions exists');
};

# ==============================================================================
# Test Group 4: Get User Error Conditions
# ==============================================================================
subtest 'Get user error conditions' => sub {
    my ($users, $storage_dir) = setup_test_env('yaml');

    # Test 1: Missing user_id
    my $result1 = $users->get_user();
    ok(!$result1->{success}, 'Fails without user_id');
    like($result1->{message}, qr/user_id is required/, 'Error about user_id');

    # Test 2: Empty user_id
    my $result2 = $users->get_user('');
    ok(!$result2->{success}, 'Fails with empty user_id');

    # Test 3: Whitespace-only user_id
    my $result3 = $users->get_user('   ');
    ok(!$result3->{success}, 'Fails with whitespace user_id');

    # Test 4: Non-existent user (but valid ID format)
    my $result4 = $users->get_user('nonexistent_user');
    ok(!$result4->{success}, 'Fails for non-existent user');
    like($result4->{message}, qr/not found/, 'Error indicates not found');
};

# ==============================================================================
# Test Group 5: Update User Error Conditions
# ==============================================================================
subtest 'Update user error conditions' => sub {
    my ($users, $storage_dir) = setup_test_env('file');

    # Test 1: Missing user_id
    my $result1 = $users->update_user();
    ok(!$result1->{success}, 'Fails without user_id');

    # Test 2: Missing updates
    my $result2 = $users->update_user('someuser');
    ok(!$result2->{success}, 'Fails without updates hash');
    like($result2->{message}, qr/hash reference/, 'Error about data type');

    # Test 3: Update non-existent user
    my $result3 = $users->update_user('nobody', { email => 'test@test.com' });
    ok(!$result3->{success}, 'Fails for non-existent user');
    like($result3->{message}, qr/not found/, 'Error indicates not found');

    # Test 4: Invalid updates data type
    my $result4 = $users->update_user('someuser', 'invalid');
    ok(!$result4->{success}, 'Fails with non-hash updates');
};

# ==============================================================================
# Test Group 6: Delete User Error Conditions
# ==============================================================================
subtest 'Delete user error conditions' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: Missing user_id
    my $result1 = $users->delete_user();
    ok(!$result1->{success}, 'Fails without user_id');

    # Test 2: Empty user_id
    my $result2 = $users->delete_user('');
    ok(!$result2->{success}, 'Fails with empty user_id');

    # Test 3: Delete non-existent user
    my $result3 = $users->delete_user('nobody');
    ok(!$result3->{success}, 'Fails for non-existent user');
    like($result3->{message}, qr/not found/, 'Error indicates not found');
};

# ==============================================================================
# Test Group 7: Edge Cases - Empty and Whitespace Values
# ==============================================================================
subtest 'Edge cases: Empty and whitespace values' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: User with empty optional fields
    my $result1 = $users->register_user({
        user_id => 'emptyfields',
        moniker => 'Empty',
        email => '',
    });
    ok($result1->{success}, 'Accepts empty optional fields');

    # Test 2: User with whitespace in fields (should be trimmed)
    my $result2 = $users->register_user({
        user_id => 'wsuser',
        moniker => '  WhitespaceUser  ',
        email => '  test@example.com  ',
    });
    ok($result2->{success}, 'Accepts and trims whitespace');

    my $verify = $users->get_user('wsuser');
    is($verify->{user}{moniker}, 'WhitespaceUser', 'Moniker trimmed');
    is($verify->{user}{email}, 'test@example.com', 'Email trimmed');
};

# ==============================================================================
# Test Group 8: Edge Cases - Special Characters
# ==============================================================================
subtest 'Edge cases: Special characters' => sub {
    my ($users, $storage_dir) = setup_test_env('yaml');

    # Test 1: Email as user_id
    my $result1 = $users->register_user({
        user_id => 'user@example.com',
        moniker => 'EmailUser',
    });
    ok($result1->{success}, 'Accepts email as user_id');

    # Test 2: user_id with dots
    my $result2 = $users->register_user({
        user_id => 'user.name@example.com',
        moniker => 'DotUser',
    });
    ok($result2->{success}, 'Accepts dots in user_id');

    # Test 3: user_id with hyphens and underscores
    my $result3 = $users->register_user({
        user_id => 'user-name_test',
        moniker => 'SpecialChar',
    });
    ok($result3->{success}, 'Accepts hyphens and underscores');
};

# ==============================================================================
# Test Group 9: Backend-Specific Edge Cases
# ==============================================================================
subtest 'Backend-specific edge cases' => sub {
    # Test 1: File backend - concurrent file access simulation
    my ($file_users, $file_dir) = setup_test_env('file');

    $file_users->register_user({
        user_id => 'concurrent',
        moniker => 'Concurrent',
        email => 'concurrent@test.com',
    });

    # Create second instance
    my $file_users2 = Concierge::Users->new("$file_dir/users-config.json");
    $file_users2->{skip_validation} = 1;

    # Both should be able to read
    my $read1 = $file_users->get_user('concurrent');
    my $read2 = $file_users2->get_user('concurrent');
    ok($read1->{success} && $read2->{success}, 'Multiple instances can read');

    # Test 2: Database backend - Special characters in allowed fields
    my ($db_users, $db_dir) = setup_test_env('database');

    # Use special characters in email field (which allows them safely)
    my $sql_result = $db_users->register_user({
        user_id => 'normal_user',
        moniker => 'NormalUser',
        email => 'test+special@example.com',
    });
    ok($sql_result->{success}, 'Handles special characters in email');

    # Verify data was stored correctly
    my $verify = $db_users->get_user('normal_user');
    ok($verify->{success}, 'User retrieved after special chars');
    is($verify->{user}{email}, 'test+special@example.com', 'Email preserved correctly');
};

# ==============================================================================
# Test Group 10: Recovery and Partial States
# ==============================================================================
subtest 'Recovery and partial states' => sub {
    my $storage_dir = tempdir(CLEANUP => 1);

    # Test 1: Instantiate from valid config after partial failure
    my $config = {
        storage_dir => $storage_dir,
        backend => 'database',
        include_standard_fields => [qw/ email /],
    };

    my $setup_result = Concierge::Users->setup($config);
    ok($setup_result->{success}, 'Setup succeeds');

    # Add some users
    my $users = Concierge::Users->new($setup_result->{config_file});
    $users->{skip_validation} = 1;

    $users->register_user({ user_id => 'user1', moniker => 'User1' });
    $users->register_user({ user_id => 'user2', moniker => 'User2' });

    # Create new instance and verify data
    my $users2 = Concierge::Users->new($setup_result->{config_file});
    $users2->{skip_validation} = 1;

    my $list = $users2->list_users();
    is($list->{total_count}, 2, 'Data persists across instances');
};

# ==============================================================================
# Test Group 11: Large Data Sets (Basic Test)
# ==============================================================================
subtest 'Large data sets (basic)' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: Register multiple users in sequence
    my $count = 50;
    for my $i (1..$count) {
        my $result = $users->register_user({
            user_id => "bulk_user_$i",
            moniker => "BulkUser$i",
            email => "user$i\@example.com",
        });
        ok($result->{success}, "Registered user $i");
    }

    # Verify all users
    my $list = $users->list_users();
    ok($list->{total_count} >= $count, "All $count users present");
};

# ==============================================================================
# Test Group 12: Readonly Field Protection
# ==============================================================================
subtest 'Readonly field protection' => sub {
    my ($users, $storage_dir) = setup_test_env('yaml');

    $users->register_user({
        user_id => 'readonly_test',
        moniker => 'ReadOnly',
        email => 'original@test.com',
    });

    my $original = $users->get_user('readonly_test');
    my $original_created = $original->{user}{created_date};

    # Attempt to update readonly fields
    my $result = $users->update_user('readonly_test', {
        user_id => 'different_id',  # Should be ignored
        created_date => '2025-01-01 00:00:00',  # Should be ignored
        email => 'updated@test.com',
    });

    ok($result->{success}, 'Update succeeds (readonly fields ignored)');

    my $updated = $users->get_user('readonly_test');
    is($updated->{user}{user_id}, 'readonly_test', 'user_id unchanged');
    is($updated->{user}{created_date}, $original_created, 'created_date unchanged');
    is($updated->{user}{email}, 'updated@test.com', 'Allowed field updated');
};

done_testing();
