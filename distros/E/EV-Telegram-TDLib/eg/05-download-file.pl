#!/usr/bin/perl
# 05-download-file.pl - download a file by id with progress reporting
#
# Demonstrates: download() with on_progress printing a percentage, and the
# local path reported once is_downloading_completed is reached. Uses the
# session created by 01-login.pl (or a bot token). File ids come from
# document/photo/video message content; they are per-session.
#
# The database directory (default ./tdlib-db) holds the session: it is
# exactly as sensitive as a password. Downloaded files land in the same
# directory tree unless files_directory says otherwise.
#
# Environment:
#   TD_API_ID, TD_API_HASH  application credentials from https://my.telegram.org
#   TD_PHONE                phone number in international format, unless TD_BOT_TOKEN
#   TD_BOT_TOKEN            bot token from BotFather, alternative to TD_PHONE
#   TD_DATABASE_DIRECTORY   optional, default ./tdlib-db
#
# Run: perl -Mblib eg/05-download-file.pl FILE_ID

use strict;
use warnings;
use EV;
use EV::Telegram::TDLib;

sub env_or_die {
    my ($name, $hint) = @_;
    return $ENV{$name} // die "missing environment variable $name ($hint)\n";
}

my $file_id = shift @ARGV or die "usage: $0 FILE_ID\n";

my %auth = $ENV{TD_BOT_TOKEN}
    ? (bot_token => $ENV{TD_BOT_TOKEN})
    : (phone_number => env_or_die('TD_PHONE', 'phone number in international format'),
       on_code => sub {
           my ($info, $submit) = @_;
           print "code from Telegram: ";
           chomp(my $code = <STDIN>);
           $submit->($code);
       });

my $td = EV::Telegram::TDLib->new(
    api_id             => env_or_die('TD_API_ID', 'api_id from https://my.telegram.org'),
    api_hash           => env_or_die('TD_API_HASH', 'api_hash from https://my.telegram.org'),
    database_directory => $ENV{TD_DATABASE_DIRECTORY} // 'tdlib-db',
    %auth,
    on_error => sub { warn "tdlib: $_[0]\n" },
);

$td->login(sub {
    my (undef, $err) = @_;
    die "login failed: $err->{message}\n" if $err;
    $td->download($file_id,
        on_progress => sub {
            my ($file) = @_;
            my $total = $file->{expected_size} // $file->{size} // 0;
            return unless $total > 0;
            my $done = $file->{local} ? $file->{local}{downloaded_size} // 0 : 0;
            printf "\r%d%%", int(100 * $done / $total);
        },
        sub {
            my ($file, $err) = @_;
            die "\ndownload failed: $err->{message}\n" if $err;
            print "\ndone: $file->{local}{path}\n";
            $td->close(sub { EV::break });
        });
});

EV::run;
