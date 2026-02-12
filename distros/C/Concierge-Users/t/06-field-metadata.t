#!/usr/bin/env perl
# Test: Field metadata and field definitions

use v5.36;
use Test2::V0;
use File::Temp qw/ tempdir /;
use Concierge::Users;
use Concierge::Users::Meta;

# ==============================================================================
# Test Group 1: init_field_meta
# ==============================================================================
subtest 'init_field_meta' => sub {
    # Test 1: All standard fields
    my $config1 = {
        include_standard_fields => 'all',
        app_fields => [],
    };

    my $field_meta1 = Concierge::Users::Meta::init_field_meta($config1);

    ok($field_meta1, 'init_field_meta returns data');
    is(ref $field_meta1, 'HASH', 'Returns hashref');
    ok($field_meta1->{fields}, 'Has fields key');
    ok($field_meta1->{field_definitions}, 'Has field_definitions key');
    is(ref $field_meta1->{fields}, 'ARRAY', 'Fields is arrayref');
    is(ref $field_meta1->{field_definitions}, 'HASH', 'Field definitions is hashref');

    # Check core fields are present
    my @core_fields = qw/ user_id moniker user_status access_level /;
    for my $field (@core_fields) {
        ok((grep { $_ eq $field } @{$field_meta1->{fields}}), "Core field '$field' present");
    }

    # Check standard fields are included
    ok((grep { $_ eq 'email' } @{$field_meta1->{fields}}), 'email field present');
    ok((grep { $_ eq 'phone' } @{$field_meta1->{fields}}), 'phone field present');

    # Check system fields
    ok((grep { $_ eq 'created_date' } @{$field_meta1->{fields}}), 'created_date present');
    ok((grep { $_ eq 'last_mod_date' } @{$field_meta1->{fields}}), 'last_mod_date present');

    # Test 2: Specific standard fields
    my $config2 = {
        include_standard_fields => [qw/ email phone /],
        app_fields => [],
    };

    my $field_meta2 = Concierge::Users::Meta::init_field_meta($config2);

    ok((grep { $_ eq 'email' } @{$field_meta2->{fields}}), 'Selected email field');
    ok((grep { $_ eq 'phone' } @{$field_meta2->{fields}}), 'Selected phone field');
    ok(!(grep { $_ eq 'first_name' } @{$field_meta2->{fields}}), 'Unselected standard field excluded');

    # Test 3: With app fields
    my $config3 = {
        include_standard_fields => [],
        app_fields => [
            { field_name => 'custom1', type => 'text', max_length => 100 },
            { field_name => 'custom2', type => 'integer' },
            'simple_field',
        ]
    };

    my $field_meta3 = Concierge::Users::Meta::init_field_meta($config3);

    ok((grep { $_ eq 'custom1' } @{$field_meta3->{fields}}), 'Custom field 1 added');
    ok((grep { $_ eq 'custom2' } @{$field_meta3->{fields}}), 'Custom field 2 added');
    ok((grep { $_ eq 'simple_field' } @{$field_meta3->{fields}}), 'Simple field added');
};

# ==============================================================================
# Test Group 2: Field Definitions Structure
# ==============================================================================
subtest 'Field definitions structure' => sub {
    my $config = {
        include_standard_fields => [qw/ email /],
        app_fields => [],
    };

    my $field_meta = Concierge::Users::Meta::init_field_meta($config);
    my $defs = $field_meta->{field_definitions};

    # Test 1: Core field definitions
    ok($defs->{user_id}, 'user_id has definition');
    is($defs->{user_id}{field_name}, 'user_id', 'field_name correct');
    is($defs->{user_id}{label}, 'User ID', 'label correct');
    is($defs->{user_id}{type}, 'system', 'type correct');
    ok($defs->{user_id}{required}, 'required flag set');
    is($defs->{user_id}{max_length}, 30, 'max_length set');

    # Test 2: Standard field definitions
    ok($defs->{email}, 'email has definition');
    is($defs->{email}{type}, 'email', 'email type correct');
    is($defs->{email}{label}, 'Email', 'email label correct');

    # Test 3: System field definitions
    ok($defs->{created_date}, 'created_date has definition');
    is($defs->{created_date}{type}, 'system', 'created_date type correct');
    is($defs->{created_date}{null_value}, '0000-00-00 00:00:00', 'null_value set');

    # Test 4: Enum field with auto-default
    ok($defs->{user_status}, 'user_status has definition');
    is($defs->{user_status}{type}, 'enum', 'user_status is enum');
    ok($defs->{user_status}{options}, 'Has options');
    is(ref $defs->{user_status}{options}, 'ARRAY', 'Options is array');
    ok($defs->{user_status}{default}, 'Auto-set default from options with *');
};

# ==============================================================================
# Test Group 3: App Field Definitions
# ==============================================================================
subtest 'App field definitions' => sub {
    my $config = {
        include_standard_fields => [],
        app_fields => [
            {
                field_name => 'bio',
                type => 'text',
                max_length => 500,
                required => 0,
                label => 'Biography',
            },
            {
                field_name => 'age',
                type => 'integer',
                required => 1,
            },
            'simple_field',
        ]
    };

    my $field_meta = Concierge::Users::Meta::init_field_meta($config);
    my $defs = $field_meta->{field_definitions};

    # Test 1: Detailed app field
    ok($defs->{bio}, 'bio field defined');
    is($defs->{bio}{field_name}, 'bio', 'bio field_name correct');
    is($defs->{bio}{type}, 'text', 'bio type correct');
    is($defs->{bio}{max_length}, 500, 'bio max_length correct');
    is($defs->{bio}{label}, 'Biography', 'bio label correct');
    is($defs->{bio}{category}, 'app', 'bio category is app');

    # Test 2: Minimal app field
    ok($defs->{age}, 'age field defined');
    is($defs->{age}{type}, 'integer', 'age type correct');
    is($defs->{age}{category}, 'app', 'age category is app');

    # Test 3: Simple string app field
    ok($defs->{simple_field}, 'simple_field defined');
    is($defs->{simple_field}{type}, 'text', 'simple field defaults to text');
    is($defs->{simple_field}{category}, 'app', 'simple field category is app');
    is($defs->{simple_field}{label}, 'Simple Field', 'Auto-generated label');
};

# ==============================================================================
# Test Group 4: Field Order Preservation
# ==============================================================================
subtest 'Field order preservation' => sub {
    my $config = {
        include_standard_fields => [qw/ email phone first_name /],
        app_fields => [
            'field1',
            'field2',
        ]
    };

    my $field_meta = Concierge::Users::Meta::init_field_meta($config);
    my @fields = @{$field_meta->{fields}};

    # Core fields come first
    is($fields[0], 'user_id', 'user_id is first');
    is($fields[1], 'moniker', 'moniker is second');

    # Standard fields in specified order
    my $email_idx = -1;
    my $phone_idx = -1;
    my $first_name_idx = -1;

    for my $i (0..$#fields) {
        $email_idx = $i if $fields[$i] eq 'email';
        $phone_idx = $i if $fields[$i] eq 'phone';
        $first_name_idx = $i if $fields[$i] eq 'first_name';
    }

    ok($email_idx > 1, 'Standard fields come after core');
    ok($phone_idx > $email_idx, 'Standard field order preserved');

    # App fields after standard
    my $field1_idx = -1;
    for my $i (0..$#fields) {
        $field1_idx = $i if $fields[$i] eq 'field1';
    }
    ok($field1_idx > $first_name_idx, 'App fields come after standard');

    # System fields at the end
    is($fields[-1], 'created_date', 'created_date is last');
    is($fields[-2], 'last_mod_date', 'last_mod_date is second to last');
};

# ==============================================================================
# Test Group 5: Integration with Setup
# ==============================================================================
subtest 'Field metadata integration with setup' => sub {
    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => 'database',
        include_standard_fields => [qw/ email phone /],
        app_fields => [
            { field_name => 'custom', type => 'text' },
        ]
    };

    my $result = Concierge::Users->setup($config);
    ok($result->{success}, 'Setup with custom fields succeeds');

    my $users = Concierge::Users->new($result->{config_file});

    # Verify fields in Users object
    ok($users->{fields}, 'Users object has fields');
    is(ref $users->{fields}, 'ARRAY', 'Fields is array');
    ok((grep { $_ eq 'custom' } @{$users->{fields}}), 'Custom field in users object');

    # Verify field definitions
    ok($users->{field_definitions}, 'Users object has field definitions');
    is($users->{field_definitions}{custom}{type}, 'text', 'Custom field definition correct');
};

# ==============================================================================
# Test Group 6: get_field_definition
# ==============================================================================
subtest 'get_field_definition' => sub {
    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => 'yaml',
        include_standard_fields => [qw/ email /],
    };

    my $result = Concierge::Users->setup($config);
    my $users = Concierge::Users->new($result->{config_file});
    $users->{skip_validation} = 1;

    # Add a user to initialize
    $users->register_user({
        user_id => 'test1',
        moniker => 'Test',
        email => 'test@test.com',
    });

    # Test 1: Get built-in field definition
    my $email_def = $users->get_field_definition('email');
    ok($email_def, 'Got email field definition');
    is($email_def->{field_name}, 'email', 'Field name correct');
    is($email_def->{type}, 'email', 'Type correct');

    # Test 2: Get core field definition
    my $user_id_def = $users->get_field_definition('user_id');
    ok($user_id_def, 'Got user_id definition');
    is($user_id_def->{required}, 1, 'user_id is required');

    # Test 3: Get system field definition
    my $created_def = $users->get_field_definition('created_date');
    ok($created_def, 'Got created_date definition');
    is($created_def->{type}, 'system', 'created_date is system type');

    # Test 4: Non-existent field
    my $missing = $users->get_field_definition('nonexistent');
    ok(!$missing, 'Non-existent field returns undef');
};

# ==============================================================================
# Test Group 7: get_field_hints
# ==============================================================================
subtest 'get_field_hints' => sub {
    my $storage_dir = tempdir(CLEANUP => 1);

    my $config = {
        storage_dir => $storage_dir,
        backend => 'database',
        include_standard_fields => [qw/ email phone /],
    };

    my $result = Concierge::Users->setup($config);
    my $users = Concierge::Users->new($result->{config_file});
    $users->{skip_validation} = 1;

    $users->register_user({
        user_id => 'test1',
        moniker => 'Test',
        email => 'test@test.com',
    });

    # Get hints for email field
    my $hints = $users->get_field_hints('email');

    ok($hints, 'Got field hints');
    is($hints->{label}, 'Email', 'Label in hints');
    is($hints->{type}, 'email', 'Type in hints');
    is($hints->{required}, 0, 'Required flag in hints');
    is($hints->{max_length}, 255, 'max_length in hints');

    # Get hints for enum field
    my $status_hints = $users->get_field_hints('user_status');
    ok($status_hints, 'Got enum field hints');
    ok($status_hints->{options}, 'Enum field has options');
    is(ref $status_hints->{options}, 'ARRAY', 'Options is array');
};

# ==============================================================================
# Test Group 8: Enum Default Auto-Setting
# ==============================================================================
subtest 'Enum default auto-setting' => sub {
    my $config = {
        include_standard_fields => [],
        app_fields => [
            {
                field_name => 'priority',
                type => 'enum',
                options => ['*low', 'medium', 'high'],
            }
        ]
    };

    my $field_meta = Concierge::Users::Meta::init_field_meta($config);
    my $defs = $field_meta->{field_definitions};

    is($defs->{priority}{default}, 'low', 'Default auto-set from * option');
    # Note: Custom app fields don't get auto-null_value unless specified
    ok(!exists $defs->{priority}{null_value} || $defs->{priority}{null_value} eq '', 'null_value handling');

    # Test without asterisk
    my $config2 = {
        include_standard_fields => [],
        app_fields => [
            {
                field_name => 'category',
                type => 'enum',
                options => ['option1', 'option2', 'option3'],
            }
        ]
    };

    my $field_meta2 = Concierge::Users::Meta::init_field_meta($config2);
    my $defs2 = $field_meta2->{field_definitions};

    is($defs2->{category}{default}, '', 'No default when no * option');
};

# ==============================================================================
# Test Group 9: Field Name Validation (Reserved Names)
# ==============================================================================
subtest 'Reserved field name handling' => sub {
    my $config = {
        include_standard_fields => [],
        app_fields => [
            'user_id',  # Try to use reserved name
            'email',    # Another reserved name
            'custom1',  # OK
        ]
    };

    # This should generate warnings but not fail
    my $field_meta = Concierge::Users::Meta::init_field_meta($config);

    # Reserved fields should be rejected
    ok(!(grep { $_ eq 'user_id' } @{$field_meta->{fields}}) ||
       (grep { $_ eq 'user_id' } @{$field_meta->{fields}}) == 1, # Only core user_id
       'Duplicate user_id rejected');

    # Custom field should be accepted
    ok((grep { $_ eq 'custom1' } @{$field_meta->{fields}}), 'custom1 accepted');
};

done_testing();
