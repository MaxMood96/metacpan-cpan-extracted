#!/usr/bin/perl
# 04-send-message.pl - send a markdown message and wait for real delivery
#
# Demonstrates: send_message with parse_mode => 'markdown' and the default
# wait => 'sent', so the callback fires on updateMessageSendSucceeded and
# carries the final message id. Uses the session created by 01-login.pl
# (or a bot token).
#
# The database directory (default ./tdlib-db) holds the session: it is
# exactly as sensitive as a password.
#
# Environment:
#   TD_API_ID, TD_API_HASH  application credentials from https://my.telegram.org
#   TD_PHONE                phone number in international format, unless TD_BOT_TOKEN
#   TD_BOT_TOKEN            bot token from BotFather, alternative to TD_PHONE
#   TD_DATABASE_DIRECTORY   optional, default ./tdlib-db
#
# Run: perl -Mblib eg/04-send-message.pl CHAT_ID [TEXT]

use strict;
use warnings;
use EV;
use EV::Telegram::TDLib;

sub env_or_die {
    my ($name, $hint) = @_;
    return $ENV{$name} // die "missing environment variable $name ($hint)\n";
}

my $chat_id = shift @ARGV or die "usage: $0 CHAT_ID [TEXT]\n";
my $text = shift @ARGV // 'hello from *EV::Telegram::TDLib*';

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

# TDLib will not send to a chat it has not loaded -- a bare user id from
# somewhere else, or your own Saved Messages -- and says so with "Chat not
# found". Opening the private chat makes it known, so this retries once.
# A bot cannot do that: it may only reply to users who started it.
sub deliver {
    my ($id, $may_open) = @_;
    $td->send_message($id, $text, parse_mode => 'markdown', sub {
        my ($msg, $err) = @_;
        if (!$err) {
            print "delivered, message id $msg->{id}\n";
            $td->close(sub { EV::break });
            return;
        }
        die "send failed: $err->{message}\n"
            unless $may_open && $id > 0 && $err->{message} =~ /Chat not found/;
        $td->send({ '@type' => 'createPrivateChat', user_id => 0 + $id }, sub {
            my ($chat, $err) = @_;
            die "cannot open a chat with $id: $err->{message}\n" if $err;
            deliver($chat->{id}, 0);
        });
    });
}

$td->login(sub {
    my (undef, $err) = @_;
    die "login failed: $err->{message}\n" if $err;
    deliver($chat_id, 1);
});


EV::run;
