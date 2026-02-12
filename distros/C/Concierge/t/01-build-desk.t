#!/usr/bin/env perl
use v5.36;
use lib 'lib';
use Test2::V0;
use File::Temp qw(tempdir);
use File::Spec;

use Concierge::Setup;

# Create temporary directory for testing
my $test_dir = tempdir(CLEANUP => 1);

subtest 'build_quick_desk basic functionality' => sub {
    my $result = Concierge::Setup::build_quick_desk(
        $test_dir,
        ['custom_field1', 'custom_field2'],  # app_fields
    );

    ok $result->{success}, 'build_quick_desk succeeds';
    ok -d $test_dir, 'desk directory exists';
    ok -f File::Spec->catfile($test_dir, 'auth.pwd'), 'auth file created';
    ok -f File::Spec->catfile($test_dir, 'concierge.conf'), 'concierge.conf created';
    ok -f File::Spec->catfile($test_dir, 'users-config.json'), 'users-config.json created';
};

subtest 'build_quick_desk validates required parameters' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);

    # Missing desk_location
    my $result = Concierge::Setup::build_quick_desk(
        undef,
    );
    ok !$result->{success}, 'fails without desk_location';
    like $result->{message}, qr/desk_location/i, 'error mentions desk_location';

};

subtest 'build_quick_desk with minimal configuration' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);

    my $result = Concierge::Setup::build_quick_desk(
        $temp_dir,
    );

    ok $result->{success}, 'build_quick_desk succeeds with minimal config';
    ok -f File::Spec->catfile($temp_dir, 'concierge.conf'), 'config created';
};

subtest 'build_quick_desk creates directory structure' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);
    my $desk_dir = File::Spec->catdir($temp_dir, 'new_desk');

    my $result = Concierge::Setup::build_quick_desk(
        $desk_dir,
    );

    ok $result->{success}, 'build_quick_desk creates missing directory';
    ok -d $desk_dir, 'new desk directory created';
};

done_testing;
