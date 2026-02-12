#!/usr/bin/env perl

use strict;
use warnings;
use Test2::V0;
use lib 'lib';

# Test that all Concierge::Sessions modules can be loaded and have correct versions

# Load main module
use Concierge::Sessions;
use Concierge::Sessions::Session;
use Concierge::Sessions::Base;
use Concierge::Sessions::SQLite;
use Concierge::Sessions::File;

# Check version numbers
my $sessions_version = $Concierge::Sessions::VERSION;
ok($sessions_version, 'Concierge::Sessions has a version');

# Verify Concierge::Sessions methods
can_ok('Concierge::Sessions', qw(new new_session get_session delete_session delete_user_session cleanup_sessions));

# Verify Concierge::Sessions::Session methods
can_ok('Concierge::Sessions::Session', qw(new get_data set_data save));
can_ok('Concierge::Sessions::Session',
    qw(is_valid is_active is_expired is_dirty));
can_ok('Concierge::Sessions::Session',
    qw(session_id created_at expires_at last_updated status storage_backend));

# Backend interface methods for Base
can_ok('Concierge::Sessions::Base',
    qw(new create_session get_session_info update_session delete_session delete_user_session cleanup_sessions generate_session_id));

# Backend interface methods for SQLite
can_ok('Concierge::Sessions::SQLite',
    qw(new create_session get_session_info update_session delete_session delete_user_session cleanup_sessions));

# Backend interface methods for File
can_ok('Concierge::Sessions::File',
    qw(new create_session get_session_info update_session delete_session delete_user_session cleanup_sessions));

done_testing;
