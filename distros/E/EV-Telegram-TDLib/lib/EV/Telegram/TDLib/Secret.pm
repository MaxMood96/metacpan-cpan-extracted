package EV::Telegram::TDLib::Secret;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES;

# A secret chat is a separate object from the chat that shows it: creating one
# yields a chat whose type is chatTypeSecret, and the id below is the secret
# chat's own id, not that chat_id. new_secret_chat returns the chat; the rest
# take the secret chat id, which lives in the chat's type.
sub new_secret_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    _need('user_id', $user_id);
    $self->send({ '@type' => 'createNewSecretChat', user_id => 0 + $user_id }, $cb);
    return;
}

sub open_secret_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($secret_chat_id, @rest) = @args;
    _need('secret_chat_id', $secret_chat_id);
    $self->send({ '@type' => 'createSecretChat',
                  secret_chat_id => 0 + $secret_chat_id }, $cb);
    return;
}

sub secret_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($secret_chat_id, @rest) = @args;
    _need('secret_chat_id', $secret_chat_id);
    $self->send({ '@type' => 'getSecretChat',
                  secret_chat_id => 0 + $secret_chat_id }, $cb);
    return;
}

sub close_secret_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($secret_chat_id, @rest) = @args;
    _need('secret_chat_id', $secret_chat_id);
    $self->send({ '@type' => 'closeSecretChat',
                  secret_chat_id => 0 + $secret_chat_id }, $cb);
    return;
}

# secret messages are not on the server, so this searches the local database
sub search_secret_messages {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query, @rest) = @args;
    my %opt = @rest;
    my %req = ('@type' => 'searchSecretMessages',
               chat_id => 0 + ($opt{chat_id} // 0),
               query   => defined $query ? "$query" : '',
               offset  => $opt{offset} // '',
               limit   => 0 + ($opt{limit} // 50));
    $req{filter} = { '@type' => $opt{filter} =~ /\AsearchMessagesFilter/
                        ? $opt{filter} : "searchMessagesFilter$opt{filter}" }
        if defined $opt{filter};
    $self->send(\%req, $cb);
    return;
}

# Changing the key rewrites the local database. Losing it loses the secret
# chats with it, since nothing on the server can restore them.
sub set_database_encryption_key {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($key, @rest) = @args;
    _need('new_encryption_key', $key);
    $self->send({ '@type' => 'setDatabaseEncryptionKey',
                  new_encryption_key => "$key" }, $cb);
    return;
}

sub session_accepts_secret_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($session_id, $on, @rest) = @args;
    _need('session_id', $session_id);
    $self->send({ '@type' => 'toggleSessionCanAcceptSecretChats',
                  session_id => "$session_id",
                  can_accept_secret_chats =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

1;
