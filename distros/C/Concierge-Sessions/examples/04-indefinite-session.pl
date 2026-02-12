#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Concierge::Sessions;

# Example: Application-wide session with indefinite timeout
# This demonstrates how to create a session that never expires,
# useful for tracking application-wide state separate from user sessions.

my $manager = Concierge::Sessions->new(
    backend     => 'database',
    storage_dir => '/tmp/app_sessions_example',
);

# Create an application-wide session that never expires
my $result = $manager->new_session(
    user_id         => 'application_main',
    session_timeout => 'indefinite',  # This session will never expire
    data            => {
        app_name     => 'MyWebApplication',
        version      => '1.0.0',
        started_at   => time(),
        status       => 'running',
        user_count   => 0,
        subsystems   => {
            database => {
                status     => 'connected',
                connection_count => 5,
                pool_size  => 10,
            },
            cache    => {
                status => 'ready',
                hit_rate => 0.85,
            },
            email    => {
                status => 'idle',
                queue_length => 0,
            },
        },
        metrics    => {
            requests_processed => 0,
            errors             => 0,
            uptime             => time(),
        },
    },
);

unless ($result->{success}) {
    die "Failed to create app session: " . $result->{message};
}

my $app_session = $result->{session};
my $session_id  = $app_session->session_id();

print "Application session created: $session_id\n";
print "Session expires at: " . $app_session->expires_at() . "\n";
print "Session is expired: " . ($app_session->is_expired() ? 'yes' : 'no') . "\n";

# Update application state
my $data_result = $app_session->get_data();
my $app_data = $data_result->{value};

$app_data->{user_count} = 42;
$app_data->{subsystems}{email}{status} = 'sending';
$app_data->{subsystems}{email}{queue_length} = 15;
$app_data->{metrics}{requests_processed} = 1500;

$app_session->set_data($app_data);
$app_session->save();

print "\nApplication state updated and saved\n";

# Later in the application code, retrieve the session
my $retrieved = $manager->get_session($session_id);

if ($retrieved->{success}) {
    my $session = $retrieved->{session};
    my $data = $session->get_data()->{value};

    print "\nCurrent application state:\n";
    print "  Name: " . $data->{app_name} . "\n";
    print "  Users: " . $data->{user_count} . "\n";
    print "  Database: " . $data->{subsystems}{database}{status} . "\n";
    print "  Email: " . $data->{subsystems}{email}{status} . "\n";
    print "  Requests processed: " . $data->{metrics}{requests_processed} . "\n";
    print "  Session expired: " . ($session->is_expired() ? 'yes' : 'no') . "\n";
}

# In contrast, user sessions can still have normal timeouts
my $user_result = $manager->new_session(
    user_id         => 'user_12345',
    session_timeout => 3600,  # Expires in 1 hour
    data            => {
        username => 'alice',
        role     => 'admin',
        login_ip => '192.168.1.100',
    },
);

print "\nUser session created with 1-hour timeout\n";
print "User session expires at: " . $user_result->{session}->expires_at() . "\n";
print "User session is expired: " . ($user_result->{session}->is_expired() ? 'yes' : 'no') . "\n";
