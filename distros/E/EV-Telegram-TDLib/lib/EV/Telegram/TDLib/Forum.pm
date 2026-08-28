package EV::Telegram::TDLib::Forum;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES;

# a topic id is a message id in disguise: TDLib uses the id of the message
# that opened the topic, so it is int53 and stays numeric
sub _icon {
    my ($opt) = @_;
    return () unless defined $opt->{color} || defined $opt->{custom_emoji_id};
    return (icon => {
        '@type'          => 'forumTopicIcon',
        color            => 0 + ($opt->{color} // 0),
        custom_emoji_id  => "" . ($opt->{custom_emoji_id} // 0),
    });
}

sub create_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $name, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, name', $chat, $name);
    $self->send({
        '@type'           => 'createForumTopic',
        chat_id           => 0 + $chat,
        name              => "$name",
        is_name_implicit  => _json_bool($opt{name_implicit}),
        _icon(\%opt),
    }, $cb);
    return;
}

sub edit_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({
        '@type'                 => 'editForumTopic',
        chat_id                 => 0 + $chat,
        forum_topic_id          => 0 + $topic,
        name                    => $opt{name} // '',
        edit_icon_custom_emoji  => _json_bool(exists $opt{custom_emoji_id}),
        icon_custom_emoji_id    => "" . ($opt{custom_emoji_id} // 0),
    }, $cb);
    return;
}

sub delete_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'deleteForumTopic',
                  chat_id => 0 + $chat, forum_topic_id => 0 + $topic }, $cb);
    return;
}

sub topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'getForumTopic',
                  chat_id => 0 + $chat, forum_topic_id => 0 + $topic }, $cb);
    return;
}

sub topics {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat);
    $self->send({
        '@type'                  => 'getForumTopics',
        chat_id                  => 0 + $chat,
        query                    => $opt{query} // '',
        offset_date              => 0 + ($opt{offset_date} // 0),
        offset_message_id        => 0 + ($opt{offset_message_id} // 0),
        offset_forum_topic_id    => 0 + ($opt{offset_forum_topic_id} // 0),
        limit                    => 0 + ($opt{limit} // 100),
    }, $cb);
    return;
}

sub topic_history {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({
        '@type'          => 'getForumTopicHistory',
        chat_id          => 0 + $chat,
        forum_topic_id   => 0 + $topic,
        from_message_id  => 0 + ($opt{from_message_id} // 0),
        offset           => 0 + ($opt{offset} // 0),
        limit            => 0 + ($opt{limit} // 50),
    }, $cb);
    return;
}

sub topic_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'getForumTopicLink',
                  chat_id => 0 + $chat, forum_topic_id => 0 + $topic }, $cb);
    return;
}

sub close_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, $closed, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'toggleForumTopicIsClosed', chat_id => 0 + $chat,
                  forum_topic_id => 0 + $topic,
                  is_closed => _json_bool(defined $closed ? $closed : 1) }, $cb);
    return;
}

sub pin_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, $pinned, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'toggleForumTopicIsPinned', chat_id => 0 + $chat,
                  forum_topic_id => 0 + $topic,
                  is_pinned => _json_bool(defined $pinned ? $pinned : 1) }, $cb);
    return;
}

sub unpin_topic_messages {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $topic, @rest) = @args;
    _need('chat_id, forum_topic_id', $chat, $topic);
    $self->send({ '@type' => 'unpinAllForumTopicMessages',
                  chat_id => 0 + $chat, forum_topic_id => 0 + $topic }, $cb);
    return;
}

sub hide_general_topic {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $hidden, @rest) = @args;
    _need('chat_id', $chat);
    $self->send({ '@type' => 'toggleGeneralForumTopicIsHidden', chat_id => 0 + $chat,
                  is_hidden => _json_bool(defined $hidden ? $hidden : 1) }, $cb);
    return;
}

sub topic_icons {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getForumTopicDefaultIcons' }, $cb);
    return;
}

1;
