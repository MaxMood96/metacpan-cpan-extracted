#!/usr/bin/env perl
# Test: Field validation system

use v5.36;
use Test2::V0;
use Test2::Tools::Exception qw/ dies lives /;
use File::Temp qw/ tempdir /;
use Concierge::Users;

# Helper to setup test environment
sub setup_test_env {
    my $backend = shift;

    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => $backend,
        include_standard_fields => [qw/ email phone first_name last_name organization /],
    };

    my $setup_result = Concierge::Users->setup($config);
    die "Setup failed: $setup_result->{message}" unless $setup_result->{success};

    my $users = Concierge::Users->new($setup_result->{config_file});

    return ($users, $storage_dir, $setup_result->{config_file});
}

# ==============================================================================
# Test Group 1: Required Fields with must_validate => 1
# ==============================================================================
subtest 'Required field validation (must_validate => 1)' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: Moniker is required and must validate
    my $result1 = $users->register_user({
        user_id => 'test1',
        moniker => '',  # Empty moniker
    });
    ok(!$result1->{success}, 'Fails with empty moniker');
    like($result1->{message}, qr/moniker/, 'Error mentions moniker');

    # Test 2: Moniker format validation
    my $result2 = $users->register_user({
        user_id => 'test2',
        moniker => 'Invalid Moniker!',  # Has space and special char
    });
    ok(!$result2->{success}, 'Fails with invalid moniker format');
    like($result2->{message}, qr/moniker/, 'Error mentions moniker');

    # Test 3: Valid moniker
    my $result3 = $users->register_user({
        user_id => 'test3',
        moniker => 'ValidMoniker42',
    });
    ok($result3->{success}, 'Accepts valid moniker');
};

# ==============================================================================
# Test Group 2: Optional Fields with must_validate => 0
# ==============================================================================
subtest 'Optional field validation (must_validate => 0)' => sub {
    my ($users, $storage_dir) = setup_test_env('file');

    # Test 1: Invalid email (must_validate=0) - should succeed with warning
    my $result1 = $users->register_user({
        user_id => 'emailtest1',
        moniker => 'EmailTest1',
        email => 'not-an-email',  # Invalid format
    });
    ok($result1->{success}, 'Succeeds but stores default (empty string) for invalid email');
    ok($result1->{warnings}, 'Has warnings about invalid email');

    # Verify email is empty string (default)
    my $check1 = $users->get_user('emailtest1');
    is($check1->{user}{email}, '', 'Invalid email not stored, default used');

    # Test 2: Valid email
    my $result2 = $users->register_user({
        user_id => 'emailtest2',
        moniker => 'EmailTest2',
        email => 'valid@example.com',
    });
    ok($result2->{success}, 'Accepts valid email');

    my $check2 = $users->get_user('emailtest2');
    is($check2->{user}{email}, 'valid@example.com', 'Valid email stored correctly');
};

# ==============================================================================
# Test Group 3: Field Type Validators
# ==============================================================================
subtest 'Field type validators' => sub {
    my ($users, $storage_dir) = setup_test_env('yaml');

    # Test 1: Phone validator (must_validate=0)
    my $result1 = $users->register_user({
        user_id => 'phonetest1',
        moniker => 'PhoneTest1',
        phone => '123',  # Too short
    });
    ok($result1->{success}, 'Succeeds with invalid phone (must_validate=0)');
    ok($result1->{warnings}, 'Has warnings about phone format');

    # Test 2: Valid phone
    my $result2 = $users->register_user({
        user_id => 'phonetest2',
        moniker => 'PhoneTest2',
        phone => '+1 (555) 123-4567',
    });
    ok($result2->{success}, 'Accepts valid phone');

    my $check2 = $users->get_user('phonetest2');
    is($check2->{user}{phone}, '+1 (555) 123-4567', 'Phone stored with internal spaces preserved');

    # Test 3: Organization field validator (must_validate=0)
    # Text validator checks max_length, organization max is 100
    my $result3 = $users->register_user({
        user_id => 'orgtest1',
        moniker => 'OrgTest1',
        organization => 'X' x 150,  # Too long (max 100)
    });
    ok($result3->{success}, 'Succeeds with invalid organization (must_validate=0)');
    ok($result3->{warnings}, 'Has warnings about organization length');

    # Test 4: Valid name fields (must_validate=1, so they must pass)
    my $result4 = $users->register_user({
        user_id => 'nametest2',
        moniker => 'NameTest2',
        first_name => 'Mary-Jane',
        last_name => "O'Brien",
    });
    ok($result4->{success}, 'Accepts valid names with hyphens and apostrophes');

    my $check4 = $users->get_user('nametest2');
    is($check4->{user}{first_name}, 'Mary-Jane', 'First name stored correctly');
    is($check4->{user}{last_name}, "O'Brien", 'Last name stored correctly');

    # Test 5: Invalid name should fail (must_validate=1)
    my $result5 = $users->register_user({
        user_id => 'nametest3',
        moniker => 'NameTest3',
        first_name => 'John123',  # Invalid - has numbers
    });
    ok(!$result5->{success}, 'Fails with invalid name (must_validate=1)');
    like($result5->{message}, qr/invalid/i, 'Error mentions invalid characters');
};

# ==============================================================================
# Test Group 4: Moniker Validation in Updates
# ==============================================================================
subtest 'Moniker validation in updates' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Create user with valid moniker
    $users->register_user({
        user_id => 'updatetest1',
        moniker => 'OriginalMoniker',
    });

    # Test 1: Try to update with invalid moniker
    my $result1 = $users->update_user('updatetest1', {
        moniker => 'Invalid Moniker!',  # Has space and special char
    });
    ok(!$result1->{success}, 'Fails to update with invalid moniker');
    like($result1->{message}, qr/moniker/, 'Error mentions moniker');

    # Verify moniker wasn't changed
    my $check1 = $users->get_user('updatetest1');
    is($check1->{user}{moniker}, 'OriginalMoniker', 'Moniker unchanged after failed update');

    # Test 2: Update with valid moniker
    my $result2 = $users->update_user('updatetest1', {
        moniker => 'UpdatedMoniker',
    });
    ok($result2->{success}, 'Accepts valid moniker update');

    my $check2 = $users->get_user('updatetest1');
    is($check2->{user}{moniker}, 'UpdatedMoniker', 'Moniker updated correctly');
};

# ==============================================================================
# Test Group 5: Warnings Accumulation
# ==============================================================================
subtest 'Warnings accumulation for multiple validation failures' => sub {
    my ($users, $storage_dir) = setup_test_env('file');

    # Register user with multiple invalid fields (all must_validate=0 except names)
    my $result = $users->register_user({
        user_id => 'warntest',
        moniker => 'WarnTest',
        email => 'invalid-email',
        phone => '123',
        organization => 'X' x 150,  # Too long
    });

    ok($result->{success}, 'Succeeds despite multiple validation failures');
    ok($result->{warnings}, 'Has warnings array');
    is(ref($result->{warnings}), 'ARRAY', 'Warnings is an array reference');

    # Should have warnings for email, phone, organization
    ok(scalar(@{$result->{warnings}}) >= 3, 'Has at least 3 warnings');

    # Verify all fields have default values
    my $check = $users->get_user('warntest');
    is($check->{user}{email}, '', 'Email is default');
    is($check->{user}{phone}, '', 'Phone is default');
    is($check->{user}{organization}, '', 'Organization is default');
};

# ==============================================================================
# Test Group 6: Data Cleaning and Trimming
# ==============================================================================
subtest 'Data cleaning before validation' => sub {
    my ($users, $storage_dir) = setup_test_env('yaml');

    # Test 1: Leading/trailing whitespace trimmed from email
    my $result1 = $users->register_user({
        user_id => 'trimtest',
        moniker => 'TrimTest',
        email => '  test@example.com  ',
    });
    ok($result1->{success}, 'Succeeds and trims email');

    my $check1 = $users->get_user('trimtest');
    is($check1->{user}{email}, 'test@example.com', 'Email trimmed correctly');

    # Test 2: Undefined values converted to empty string
    my $result2 = $users->register_user({
        user_id => 'undef-test',
        moniker => 'UndefTest',
        email => undef,
        phone => undef,
    });
    ok($result2->{success}, 'Handles undefined values');

    my $check2 = $users->get_user('undef-test');
    is($check2->{user}{email}, '', 'Undef email becomes empty string');
    is($check2->{user}{phone}, '', 'Undef phone becomes empty string');

    # Test 3: Internal whitespace preserved in valid data
    my $result3 = $users->register_user({
        user_id => 'internal-space-test',
        moniker => 'InternalSpace',
        organization => 'ACME Corporation Inc',  # Internal spaces are OK
    });
    ok($result3->{success}, 'Accepts internal whitespace in text fields');

    my $check3 = $users->get_user('internal-space-test');
    is($check3->{user}{organization}, 'ACME Corporation Inc', 'Internal spaces preserved');
};

# ==============================================================================
# Test Group 7: Required vs Optional Fields
# ==============================================================================
subtest 'Required fields enforcement' => sub {
    my ($users, $storage_dir) = setup_test_env('database');

    # Test 1: Missing required field (moniker)
    my $result1 = $users->register_user({
        user_id => 'requiredtest1',
        # moniker is missing
    });
    ok(!$result1->{success}, 'Fails without required moniker');
    like($result1->{message}, qr/moniker.*required/i, 'Error says moniker is required');

    # Test 2: All required fields provided, optional missing
    my $result2 = $users->register_user({
        user_id => 'requiredtest2',
        moniker => 'RequiredTest2',
        # email, phone, first_name, last_name all missing (optional)
    });
    ok($result2->{success}, 'Succeeds with only required fields');

    my $check2 = $users->get_user('requiredtest2');
    is($check2->{user}{email}, '', 'Optional email is default');
    is($check2->{user}{phone}, '', 'Optional phone is default');
};

# ==============================================================================
# Test Group 8: Readonly Field Protection
# ==============================================================================
subtest 'Readonly fields in validation' => sub {
    my ($users, $storage_dir) = setup_test_env('file');

    # Create user
    $users->register_user({
        user_id => 'readonlytest',
        moniker => 'ReadOnlyTest',
        email => 'original@example.com',
    });

    my $original = $users->get_user('readonlytest');
    my $original_created = $original->{user}{created_date};

    # Try to update readonly field
    my $result = $users->update_user('readonlytest', {
        created_date => '2025-01-01 00:00:00',  # Readonly
        email => 'updated@example.com',
    });

    ok($result->{success}, 'Update succeeds');

    my $updated = $users->get_user('readonlytest');
    is($updated->{user}{created_date}, $original_created, 'created_date unchanged');
    is($updated->{user}{email}, 'updated@example.com', 'Email updated');
};

done_testing();
