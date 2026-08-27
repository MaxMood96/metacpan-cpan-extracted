#!/usr/bin/perl
# 01-login.pl - user login with phone number, SMS code and 2FA password
#
# Demonstrates: phone_number authorization, the on_code and on_password
# credential callbacks, me(), and a clean close.
#
# This is the script that creates the session database; the other examples
# reuse it. The database directory (default ./tdlib-db) holds the session:
# it is exactly as sensitive as a password, so do not commit it, back it up,
# or leave it world-readable.
#
# Environment:
#   TD_API_ID, TD_API_HASH  application credentials from https://my.telegram.org
#   TD_PHONE                phone number in international format, e.g. +10000000000
#   TD_DATABASE_DIRECTORY   optional, default ./tdlib-db
#
# Run: perl -Mblib eg/01-login.pl

use strict;
use warnings;
use EV;
use EV::Telegram::TDLib;

sub env_or_die {
    my ($name, $hint) = @_;
    return $ENV{$name} // die "missing environment variable $name ($hint)\n";
}

my $td = EV::Telegram::TDLib->new(
    api_id             => env_or_die('TD_API_ID', 'api_id from https://my.telegram.org'),
    api_hash           => env_or_die('TD_API_HASH', 'api_hash from https://my.telegram.org'),
    phone_number       => env_or_die('TD_PHONE', 'phone number in international format'),
    database_directory => $ENV{TD_DATABASE_DIRECTORY} // 'tdlib-db',
    on_code => sub {
        my ($info, $submit) = @_;
        print "code from Telegram: ";
        chomp(my $code = <STDIN>);
        $submit->($code);
    },
    on_password => sub {
        my ($info, $submit) = @_;
        my $hint = $info->{password_hint};
        print "2FA password", (defined $hint && length $hint ? " (hint: $hint)" : ''), ": ";
        chomp(my $password = <STDIN>);
        $submit->($password);
    },
    on_error => sub { warn "tdlib: $_[0]\n" },
);

$td->login(sub {
    my (undef, $err) = @_;
    die "login failed: $err->{message}\n" if $err;
    $td->me(sub {
        my ($user, $err) = @_;
        die "getMe failed: $err->{message}\n" if $err;
        # user has no top-level username; the usernames object holds them
        my $names = $user->{usernames} // {};
        my $username = ($names->{active_usernames} // [])->[0]
            // $names->{editable_username};
        printf "logged in as %s %s (id %d%s)\n",
            $user->{first_name}, $user->{last_name} // '', $user->{id},
            defined $username ? ", \@$username" : '';
        $td->close(sub { EV::break });
    });
});

EV::run;
