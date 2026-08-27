package EV::Telegram::TDLib::Chats;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.02';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

# updates whose payload fields overwrite the same-named cached chat fields;
# positions ride along on some of them and are merged per list below
my %CHAT_FIELDS = (
    updateChatTitle                      => ['title'],
    updateChatPhoto                      => ['photo'],
    updateChatPermissions                => ['permissions'],
    updateChatLastMessage                => ['last_message'],
    updateChatDraftMessage               => ['draft_message'],
    updateChatReadInbox                  => ['last_read_inbox_message_id', 'unread_count'],
    updateChatReadOutbox                 => ['last_read_outbox_message_id'],
    updateChatUnreadMentionCount         => ['unread_mention_count'],
    updateChatNotificationSettings       => ['notification_settings'],
    updateChatIsMarkedAsUnread           => ['is_marked_as_unread'],
    updateChatBlockList                  => ['block_list'],
    updateChatHasScheduledMessages       => ['has_scheduled_messages'],
    updateChatDefaultDisableNotification => ['default_disable_notification'],
    updateChatActionBar                  => ['action_bar'],
    updateChatTheme                      => ['theme'],
    updateChatAvailableReactions         => ['available_reactions'],
    updateChatPendingJoinRequests        => ['pending_join_requests'],
    updateChatMessageAutoDeleteTime      => ['message_auto_delete_time'],
);

our %UPDATES = (
    updateNewChat      => \&_update_new_chat,
    updateChatPosition => \&_update_chat_position,
    (map { $_ => \&_update_chat_fields } keys %CHAT_FIELDS),
);

sub _chats { $_[0]{cache}{chats} ||= {} }

sub _update_new_chat {
    my ($self, $obj) = @_;
    my $chat = $obj->{chat} or return;
    $self->_chats->{ $chat->{id} } = $chat;
    if (my $cb = $self->{on_chat}) { $cb->($chat) }
}

# an update carries only the positions that changed; order 0 means the chat
# left that list
sub _merge_positions {
    my ($chat, $incoming) = @_;
    return unless $incoming;
    my $positions = $chat->{positions} ||= [];
    for my $pos (@$incoming) {
        my $list = $pos->{list}{'@type'} // '';
        @$positions = grep { ($_->{list}{'@type'} // '') ne $list } @$positions;
        push @$positions, $pos unless ($pos->{order} // 0) eq '0';
    }
}

# payload fields the schema marks nullable: TDLib omits a null object
# field from the JSON entirely, so for these an absent key means
# "now null", not "unchanged"
my %NULLABLE = map { $_ => 1 } qw(
    last_message draft_message photo action_bar theme block_list
    pending_join_requests
);

sub _update_chat_fields {
    my ($self, $obj) = @_;
    my $fields = $CHAT_FIELDS{ $obj->{'@type'} } or return;
    return unless defined $obj->{chat_id};
    my $chat = $self->_chats->{ $obj->{chat_id} } or return;
    for my $f (@$fields) {
        $chat->{$f} = $obj->{$f} if $NULLABLE{$f} || exists $obj->{$f};
    }
    _merge_positions($chat, $obj->{positions});
}

sub _update_chat_position {
    my ($self, $obj) = @_;
    return unless defined $obj->{chat_id};
    my $chat = $self->_chats->{ $obj->{chat_id} } or return;
    _merge_positions($chat, [ $obj->{position} ]) if $obj->{position};
}

sub chat {
    my ($self, $id) = @_;
    return $self->_chats->{$id};
}

sub on_chat {
    my ($self, $cb) = @_;
    $self->{on_chat} = $cb if $cb;
    return $self->{on_chat};
}

sub load_chats {
    my ($self, $limit, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'loadChats', limit => 0 + $limit }, sub {
        my ($res, $err) = @_;
        # TDLib answers 404 once the chat list is exhausted; that is the
        # normal end of a load, not a failure
        $err = undef if $err && ($err->{code} // 0) == 404;
        $cb->($res, $err);
    });
}

sub chat_by_username {
    my ($self, $name, $cb) = @_;
    $cb ||= sub {};
    $name =~ s/^\@//;
    $self->send({ '@type' => 'searchPublicChat', username => $name }, sub {
        my ($chat, $err) = @_;
        $self->_chats->{ $chat->{id} } = $chat if $chat;
        $cb->($chat, $err);
    });
}

# TDLib only makes a read stick while the chat is open, so both requests
# are sent as a pair
sub mark_read {
    my ($self, $chat_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $ids = $opt{message_ids};
    if (!$ids || !@$ids) {
        my $last = eval { $self->chat($chat_id)->{last_message}{id} };
        $ids = $last ? [$last] : [];
    }
    if (!@$ids) {
        $cb->(undef, { '@type' => 'error', code => -1,
                       message => 'nothing to mark read in chat ' . $chat_id });
        return;
    }
    $self->send({ '@type' => 'openChat', chat_id => 0 + $chat_id }, sub {
        my (undef, $err) = @_;
        if ($err) { $cb->(undef, $err); return }
        $self->send({
            '@type'      => 'viewMessages',
            chat_id      => 0 + $chat_id,
            message_ids  => [ map { 0 + $_ } @$ids ],
            source       => { '@type' => 'messageSourceChatHistory' },
            force_read   => _json_bool(1),
        }, $cb);
    });
    return;
}

my %CHAT_ACTION = (
    typing           => 'chatActionTyping',
    upload_document  => 'chatActionUploadingDocument',
    upload_photo     => 'chatActionUploadingPhoto',
    upload_video     => 'chatActionUploadingVideo',
    upload_voice     => 'chatActionUploadingVoiceNote',
    record_video     => 'chatActionRecordingVideo',
    record_voice     => 'chatActionRecordingVoiceNote',
    cancel           => 'chatActionCancel',
);

sub chat_action {
    my ($self, $chat_id, $action, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    $action = 'typing' unless defined $action;
    my $type = $CHAT_ACTION{$action}
        or croak "unknown chat action '$action'";
    $self->send({ '@type' => 'sendChatAction', chat_id => 0 + $chat_id,
                  action => { '@type' => $type } }, $cb);
    return;
}

sub join_chat {
    my ($self, $chat_id, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'joinChat', chat_id => 0 + $chat_id }, $cb);
    return;
}

sub leave_chat {
    my ($self, $chat_id, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'leaveChat', chat_id => 0 + $chat_id }, $cb);
    return;
}

sub pin_message {
    my ($self, $chat_id, $message_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, message_id', $chat_id, $message_id);
    $self->send({
        '@type'              => 'pinChatMessage',
        chat_id              => 0 + $chat_id,
        message_id           => 0 + $message_id,
        disable_notification => _json_bool($opt{silent}),
        only_for_self        => _json_bool($opt{only_for_self}),
    }, $cb);
    return;
}

sub unpin_message {
    my ($self, $chat_id, $message_id, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'unpinChatMessage', chat_id => 0 + $chat_id,
                  message_id => 0 + $message_id }, $cb);
    return;
}

sub set_chat_title {
    my ($self, $chat_id, $title, $cb) = @_;
    $cb ||= sub {};
    croak 'set_chat_title needs a title' unless defined $title && length $title;
    $self->send({ '@type' => 'setChatTitle', chat_id => 0 + $chat_id,
                  title => "$title" }, $cb);
    return;
}

sub set_chat_photo {
    my ($self, $chat_id, $path, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    $self->send({ '@type' => 'setChatPhoto', chat_id => 0 + $chat_id,
                  photo => $self->_input_chat_photo($path, \%opt) }, $cb);
    return;
}

sub add_chat_member {
    my ($self, $chat_id, $user_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, user_id', $chat_id, $user_id);
    $self->send({
        '@type'        => 'addChatMember',
        chat_id        => 0 + $chat_id,
        user_id        => 0 + $user_id,
        forward_limit  => 0 + ($opt{forward_limit} // 0),
    }, $cb);
    return;
}

my %MEMBER_STATUS = (
    member  => 'chatMemberStatusMember',
    left    => 'chatMemberStatusLeft',
    banned  => 'chatMemberStatusBanned',
);

# 'banned' removes and blocks; 'left' is the plain kick that lets them back
sub set_member_status {
    my ($self, $chat_id, $user_id, $status, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $type = $MEMBER_STATUS{ $status // '' }
        or croak "unknown member status '" . ($status // '') . "'";
    my %st = ('@type' => $type);
    $st{banned_until_date} = 0 + ($opt{until} // 0) if $status eq 'banned';
    $st{member_until_date} = 0 + ($opt{until} // 0) if $status eq 'member';
    $self->send({
        '@type'    => 'setChatMemberStatus',
        chat_id    => 0 + $chat_id,
        member_id  => { '@type' => 'messageSenderUser', user_id => 0 + $user_id },
        status     => \%st,
    }, $cb);
    return;
}

sub block_user {
    my ($self, $user_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('user_id', $user_id);
    $self->send({
        '@type'      => 'setMessageSenderBlockList',
        sender_id    => { '@type' => 'messageSenderUser', user_id => 0 + $user_id },
        # an undefined block list is what unblocking is
        block_list   => $opt{unblock} ? undef
                      : { '@type' => $opt{stories} ? 'blockListStories' : 'blockListMain' },
    }, $cb);
    return;
}

1;
