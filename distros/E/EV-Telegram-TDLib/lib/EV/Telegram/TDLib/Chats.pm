package EV::Telegram::TDLib::Chats;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

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
    updateNewChatJoinRequest    => \&_update_join_request,
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $action, @rest) = @args;
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, @rest) = @args;
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $path, @rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'setChatPhoto', chat_id => 0 + $chat_id,
                  photo => $self->_input_chat_photo($path, \%opt) }, $cb);
    return;
}

sub add_chat_member {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, @rest) = @args;
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, $status, @rest) = @args;
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
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
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

sub _sender { { '@type' => 'messageSenderUser', user_id => 0 + $_[0] } }

sub member {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, @rest) = @args;
    _need('chat_id, user_id', $chat_id, $user_id);
    $self->send({ '@type' => 'getChatMember', chat_id => 0 + $chat_id,
                  member_id => _sender($user_id) }, $cb);
    return;
}

sub admins {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'getChatAdministrators', chat_id => 0 + $chat_id }, $cb);
    return;
}

# spelled out rather than derived: xt/schema_pin.t verifies these against
# td_api.h, and a name built by interpolation is invisible to that check
my %MEMBER_FILTER = (
    contacts       => 'chatMembersFilterContacts',
    administrators => 'chatMembersFilterAdministrators',
    members        => 'chatMembersFilterMembers',
    restricted     => 'chatMembersFilterRestricted',
    banned         => 'chatMembersFilterBanned',
    bots           => 'chatMembersFilterBots',
);

sub search_members {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $query, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    my %req = ('@type' => 'searchChatMembers', chat_id => 0 + $chat_id,
               query => defined $query ? "$query" : '',
               limit => 0 + ($opt{limit} // 50));
    if (defined $opt{filter}) {
        my $t = $MEMBER_FILTER{ $opt{filter} }
            or croak "unknown member filter '$opt{filter}'";
        $req{filter} = { '@type' => $t };
    }
    $self->send(\%req, $cb);
    return;
}

# every permission chatPermissions defines; the order is the schema's
my @PERMISSIONS = qw(
    can_send_basic_messages can_send_audios can_send_documents can_send_photos
    can_send_videos can_send_video_notes can_send_voice_notes can_send_polls
    can_send_other_messages can_add_link_previews can_react_to_messages
    can_edit_tag can_change_info can_invite_users can_pin_messages
    can_create_topics
);
my %PERMISSION = map { $_ => 1 } @PERMISSIONS;

# TDLib replaces the whole set, so anything absent is denied. An unknown key
# is refused rather than ignored: a typo would silently take a right away.
sub set_permissions {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $perms, @rest) = @args;
    _need('chat_id, permissions', $chat_id, $perms);
    croak 'set_permissions needs a hashref of permissions' unless ref $perms eq 'HASH';
    if (my @bad = sort grep { !$PERMISSION{$_} } keys %$perms) {
        croak "unknown permission(s): @bad";
    }
    $self->send({
        '@type'      => 'setChatPermissions',
        chat_id      => 0 + $chat_id,
        permissions  => { '@type' => 'chatPermissions',
                          map { $_ => _json_bool($perms->{$_}) } @PERMISSIONS },
    }, $cb);
    return;
}

sub set_chat_description {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $text, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'setChatDescription', chat_id => 0 + $chat_id,
                  description => defined $text ? "$text" : '' }, $cb);
    return;
}

sub invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({
        '@type'                => 'createChatInviteLink',
        chat_id                => 0 + $chat_id,
        name                   => $opt{name} // '',
        expiration_date        => 0 + ($opt{expires} // 0),
        member_limit           => 0 + ($opt{limit} // 0),
        creates_join_request   => _json_bool($opt{join_request}),
    }, $cb);
    return;
}

sub edit_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $link, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, invite_link', $chat_id, $link);
    $self->send({
        '@type'                => 'editChatInviteLink',
        chat_id                => 0 + $chat_id,
        invite_link            => "$link",
        name                   => $opt{name} // '',
        expiration_date        => 0 + ($opt{expires} // 0),
        member_limit           => 0 + ($opt{limit} // 0),
        creates_join_request   => _json_bool($opt{join_request}),
    }, $cb);
    return;
}

sub invite_links {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({
        '@type'              => 'getChatInviteLinks',
        chat_id              => 0 + $chat_id,
        creator_user_id      => 0 + ($opt{creator} // 0),
        is_revoked           => _json_bool($opt{revoked}),
        offset_date          => 0 + ($opt{offset_date} // 0),
        offset_invite_link   => $opt{offset_link} // '',
        limit                => 0 + ($opt{limit} // 100),
    }, $cb);
    return;
}

sub revoke_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $link, @rest) = @args;
    _need('chat_id, invite_link', $chat_id, $link);
    $self->send({ '@type' => 'revokeChatInviteLink', chat_id => 0 + $chat_id,
                  invite_link => "$link" }, $cb);
    return;
}

sub replace_primary_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'replacePrimaryChatInviteLink',
                  chat_id => 0 + $chat_id }, $cb);
    return;
}

sub invite_link_members {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $link, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, invite_link', $chat_id, $link);
    $self->send({
        '@type'                          => 'getChatInviteLinkMembers',
        chat_id                          => 0 + $chat_id,
        invite_link                      => "$link",
        only_with_expired_subscription   => _json_bool($opt{expired_only}),
        limit                            => 0 + ($opt{limit} // 100),
    }, $cb);
    return;
}

# these two take only the link: the chat is whatever the link points at
sub check_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($link, @rest) = @args;
    _need('invite_link', $link);
    $self->send({ '@type' => 'checkChatInviteLink', invite_link => "$link" }, $cb);
    return;
}

sub join_by_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($link, @rest) = @args;
    _need('invite_link', $link);
    $self->send({ '@type' => 'joinChatByInviteLink', invite_link => "$link" }, $cb);
    return;
}

my %CHAT_LIST = (
    main    => 'chatListMain',
    archive => 'chatListArchive',
);

# a chat list is either of the two built-in ones or a folder by id
sub _chat_list {
    my ($which) = @_;
    $which = 'main' unless defined $which;
    return { '@type' => 'chatListFolder', chat_folder_id => 0 + $which }
        if $which =~ /\A[0-9]+\z/;
    my $t = $CHAT_LIST{$which} or croak "unknown chat list '$which'";
    return { '@type' => $t };
}

# every use_default_* stays true so muting does not quietly reset the sound,
# previews or the other notification choices along with it
sub mute {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $seconds, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({
        '@type'  => 'setChatNotificationSettings',
        chat_id  => 0 + $chat_id,
        notification_settings => {
            '@type'               => 'chatNotificationSettings',
            use_default_mute_for  => _json_bool(0),
            mute_for              => 0 + (defined $seconds ? $seconds : 2147483647),
            map { $_ => _json_bool(1) } qw(
                use_default_sound use_default_show_preview
                use_default_mute_stories use_default_story_sound
                use_default_show_story_poster
                use_default_disable_pinned_message_notifications
                use_default_disable_mention_notifications),
        },
    }, $cb);
    return;
}

sub unmute { my ($self, $chat_id, @rest) = @_; $self->mute($chat_id, 0, @rest) }

sub archive {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'addChatToList', chat_id => 0 + $chat_id,
                  chat_list => _chat_list('archive') }, $cb);
    return;
}

sub unarchive {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'addChatToList', chat_id => 0 + $chat_id,
                  chat_list => _chat_list('main') }, $cb);
    return;
}

sub pin_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $pinned, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'toggleChatIsPinned', chat_id => 0 + $chat_id,
                  chat_list => _chat_list($opt{list}),
                  is_pinned => _json_bool(defined $pinned ? $pinned : 1) }, $cb);
    return;
}

sub mark_unread {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $unread, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'toggleChatIsMarkedAsUnread', chat_id => 0 + $chat_id,
                  is_marked_as_unread =>
                      _json_bool(defined $unread ? $unread : 1) }, $cb);
    return;
}

sub chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'getChats', chat_list => _chat_list($opt{list}),
                  limit => 0 + ($opt{limit} // 100) }, $cb);
    return;
}

# the global counterpart of search_messages, which searches one chat
sub search_all {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query, @rest) = @args;
    my %opt = @rest;
    _need('query', $query);
    $self->send({
        '@type'    => 'searchMessages',
        chat_list  => _chat_list($opt{list}),
        query      => "$query",
        offset     => $opt{offset} // '',
        limit      => 0 + ($opt{limit} // 50),
        min_date   => 0 + ($opt{min_date} // 0),
        max_date   => 0 + ($opt{max_date} // 0),
    }, $cb);
    return;
}

my %SCOPE = (
    private  => 'notificationSettingsScopePrivateChats',
    groups   => 'notificationSettingsScopeGroupChats',
    channels => 'notificationSettingsScopeChannelChats',
);

sub _scope {
    my ($which) = @_;
    my $t = $SCOPE{ $which // '' } or croak "unknown notification scope '"
        . ($which // '') . "'";
    return { '@type' => $t };
}

# all nine fields are sent outright; the story defaults leave stories
# alone: nothing muted, the default sound kept, the poster shown
sub mute_scope {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($scope, $seconds, @rest) = @args;
    my %opt = @rest;
    _need('scope', $scope);
    $self->send({
        '@type' => 'setScopeNotificationSettings',
        scope   => _scope($scope),
        notification_settings => {
            '@type'        => 'scopeNotificationSettings',
            mute_for       => 0 + (defined $seconds ? $seconds : 2147483647),
            sound_id       => "" . ($opt{sound_id} // 0),
            show_preview   => _json_bool(exists $opt{preview} ? $opt{preview} : 1),
            use_default_mute_stories => _json_bool(!exists $opt{mute_stories}),
            mute_stories   => _json_bool($opt{mute_stories}),
            story_sound_id => "" . ($opt{story_sound_id} // 0),
            show_story_poster =>
                _json_bool(exists $opt{show_story_poster} ? $opt{show_story_poster} : 1),
            disable_pinned_message_notifications => _json_bool($opt{no_pinned}),
            disable_mention_notifications        => _json_bool($opt{no_mentions}),
        },
    }, $cb);
    return;
}

sub scope_settings {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($scope, @rest) = @args;
    _need('scope', $scope);
    $self->send({ '@type' => 'getScopeNotificationSettings',
                  scope => _scope($scope) }, $cb);
    return;
}

sub reset_notifications {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'resetAllNotificationSettings' }, $cb);
    return;
}

# 'all' allows every reaction the chat's tier permits; an arrayref names them
sub set_chat_reactions {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $reactions, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, reactions', $chat_id, $reactions);
    my $avail;
    if (ref $reactions eq 'ARRAY') {
        $avail = {
            '@type'    => 'chatAvailableReactionsSome',
            reactions  => [ map { { '@type' => 'reactionTypeEmoji', emoji => "$_" } }
                            @$reactions ],
            max_reaction_count => 0 + ($opt{max} // 11),
        };
    }
    elsif ($reactions eq 'all') {
        $avail = { '@type' => 'chatAvailableReactionsAll',
                   max_reaction_count => 0 + ($opt{max} // 11) };
    }
    else { croak "set_chat_reactions takes 'all' or an arrayref of emoji" }
    $self->send({ '@type' => 'setChatAvailableReactions',
                  chat_id => 0 + $chat_id, available_reactions => $avail }, $cb);
    return;
}

sub blocked {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'      => 'getBlockedMessageSenders',
        block_list   => { '@type' => ($opt{stories} ? 'blockListStories'
                                                    : 'blockListMain') },
        offset       => 0 + ($opt{offset} // 0),
        limit        => 0 + ($opt{limit} // 100),
    }, $cb);
    return;
}

sub join_requests {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({
        '@type'          => 'getChatJoinRequests',
        chat_id          => 0 + $chat_id,
        invite_link      => $opt{link} // '',
        query            => $opt{query} // '',
        limit            => 0 + ($opt{limit} // 100),
    }, $cb);
    return;
}

sub process_join_request {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, $approve, @rest) = @args;
    _need('chat_id, user_id', $chat_id, $user_id);
    $self->send({ '@type' => 'processChatJoinRequest', chat_id => 0 + $chat_id,
                  user_id => 0 + $user_id,
                  approve => _json_bool(defined $approve ? $approve : 1) }, $cb);
    return;
}

# approves or declines everyone at once, optionally only those from one link
sub process_join_requests {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $approve, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'processChatJoinRequests', chat_id => 0 + $chat_id,
                  invite_link => $opt{link} // '',
                  approve => _json_bool(defined $approve ? $approve : 1) }, $cb);
    return;
}

sub on_join_request {
    my ($self, $cb) = @_;
    $self->{on_join_request} = $cb if $cb;
    return $self->{on_join_request};
}

sub _update_join_request {
    my ($self, $obj) = @_;
    my $cb = $self->{on_join_request} or return;
    my $r = $obj->{request} || {};
    $cb->({
        chat_id       => $obj->{chat_id},
        user_id       => $r->{user_id},
        date          => $r->{date},
        bio           => $r->{bio},
        invite_link   => $obj->{invite_link},
        user_chat_id  => $obj->{user_chat_id},
    });
}

# A supergroup's chat id is -1000000000000 minus its supergroup id, and the
# supergroup_* methods want the latter. Everything else in this module takes a
# chat id, so accept either and convert rather than let the mismatch surface as
# an unhelpful server error.
sub _supergroup_id {
    my ($id) = @_;
    return 0 + $id unless $id < 0;
    return -1000000000000 - $id;
}

sub add_members {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_ids, @rest) = @args;
    _need('chat_id, user_ids', $chat_id, $user_ids);
    croak 'add_members needs an arrayref of user ids' unless ref $user_ids eq 'ARRAY';
    $self->send({ '@type' => 'addChatMembers', chat_id => 0 + $chat_id,
                  user_ids => [ map { 0 + $_ } @$user_ids ] }, $cb);
    return;
}

# revoke also deletes what they already sent, which set_member_status does not
sub ban_member {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, user_id', $chat_id, $user_id);
    $self->send({ '@type' => 'banChatMember', chat_id => 0 + $chat_id,
                  member_id => _sender($user_id),
                  banned_until_date => 0 + ($opt{until} // 0),
                  revoke_messages => _json_bool($opt{revoke}) }, $cb);
    return;
}

sub transfer_ownership {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $user_id, $password, @rest) = @args;
    _need('chat_id, user_id, password', $chat_id, $user_id, $password);
    $self->send({ '@type' => 'transferChatOwnership', chat_id => 0 + $chat_id,
                  user_id => 0 + $user_id, password => "$password" }, $cb);
    return;
}

sub set_default_admin_rights {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($rights, @rest) = @args;
    my %opt = @rest;
    _need('rights', $rights);
    croak 'set_default_admin_rights needs a chatAdministratorRights hashref'
        unless ref $rights eq 'HASH';
    my $channel = $opt{channel} ? 1 : 0;
    $self->send($channel
        ? { '@type' => 'setDefaultChannelAdministratorRights',
            default_channel_administrator_rights => $rights }
        : { '@type' => 'setDefaultGroupAdministratorRights',
            default_group_administrator_rights => $rights }, $cb);
    return;
}

sub create_group {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($title, @rest) = @args;
    my %opt = @rest;
    _need('title', $title);
    # a basic group needs its members up front; a supergroup is created empty
    if ($opt{members}) {
        croak 'members must be an arrayref' unless ref $opt{members} eq 'ARRAY';
        $self->send({ '@type' => 'createNewBasicGroupChat',
                      user_ids => [ map { 0 + $_ } @{ $opt{members} } ],
                      title => "$title",
                      message_auto_delete_time => 0 + ($opt{auto_delete} // 0) }, $cb);
        return;
    }
    $self->send({
        '@type'                   => 'createNewSupergroupChat',
        title                     => "$title",
        is_forum                  => _json_bool($opt{forum}),
        is_channel                => _json_bool($opt{channel}),
        description               => $opt{description} // '',
        message_auto_delete_time  => 0 + ($opt{auto_delete} // 0),
        for_import                => _json_bool($opt{for_import}),
    }, $cb);
    return;
}

sub upgrade_to_supergroup {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'upgradeBasicGroupChatToSupergroupChat',
                  chat_id => 0 + $chat_id }, $cb);
    return;
}

sub delete_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'deleteChat', chat_id => 0 + $chat_id }, $cb);
    return;
}

# revoke deletes the history for everyone, not only for us
sub delete_history {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'deleteChatHistory', chat_id => 0 + $chat_id,
                  remove_from_chat_list => _json_bool($opt{remove_from_list}),
                  revoke => _json_bool($opt{revoke}) }, $cb);
    return;
}

sub set_slow_mode {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $seconds, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'setChatSlowModeDelay', chat_id => 0 + $chat_id,
                  slow_mode_delay => 0 + ($seconds // 0) }, $cb);
    return;
}

sub set_auto_delete {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $seconds, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'setChatMessageAutoDeleteTime', chat_id => 0 + $chat_id,
                  message_auto_delete_time => 0 + ($seconds // 0) }, $cb);
    return;
}

sub set_discussion_group {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $discussion, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'setChatDiscussionGroup', chat_id => 0 + $chat_id,
                  discussion_chat_id => 0 + ($discussion // 0) }, $cb);
    return;
}

sub protect_content {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $on, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'toggleChatHasProtectedContent', chat_id => 0 + $chat_id,
                  has_protected_content =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

# --- supergroup switches. These take a supergroup id, but accept a chat id too.
sub make_forum {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    my %opt = @rest;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupIsForum',
                  supergroup_id => _supergroup_id($id),
                  is_forum       => _json_bool(defined $on ? $on : 1),
                  has_forum_tabs => _json_bool($opt{tabs}) }, $cb);
    return;
}

sub sign_messages {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    my %opt = @rest;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupSignMessages',
                  supergroup_id => _supergroup_id($id),
                  sign_messages => _json_bool(defined $on ? $on : 1),
                  show_message_sender => _json_bool($opt{show_sender}) }, $cb);
    return;
}

sub join_by_request {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    my %opt = @rest;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupJoinByRequest',
                  supergroup_id  => _supergroup_id($id),
                  join_by_request => _json_bool(defined $on ? $on : 1),
                  guard_bot_user_id => 0 + ($opt{guard_bot} // 0),
                  apply_to_invite_links => _json_bool($opt{apply_to_links}) }, $cb);
    return;
}

sub join_to_send {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupJoinToSendMessages',
                  supergroup_id => _supergroup_id($id),
                  join_to_send_messages =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

sub all_history_available {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupIsAllHistoryAvailable',
                  supergroup_id => _supergroup_id($id),
                  is_all_history_available =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

sub hide_members {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $on, @rest) = @args;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'toggleSupergroupHasHiddenMembers',
                  supergroup_id => _supergroup_id($id),
                  has_hidden_members =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

sub set_supergroup_username {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $username, @rest) = @args;
    _need('supergroup_id', $id);
    $self->send({ '@type' => 'setSupergroupUsername',
                  supergroup_id => _supergroup_id($id),
                  username => defined $username ? "$username" : '' }, $cb);
    return;
}

# chat() reads the module's cache; this asks TDLib, which also loads a chat
# the client has not seen yet
sub fetch_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'getChat', chat_id => 0 + $chat_id }, $cb);
    return;
}

# mark_read opens a chat and nothing closes it; do that when you are done
# with one, or TDLib keeps it in its active set
sub close_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'closeChat', chat_id => 0 + $chat_id }, $cb);
    return;
}

sub user_full_info {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    _need('user_id', $user_id);
    $self->send({ '@type' => 'getUserFullInfo', user_id => 0 + $user_id }, $cb);
    return;
}

# takes a chat id or a supergroup id; full => 1 asks for the fuller record
sub supergroup {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('supergroup_id', $id);
    $self->send({ '@type' => $opt{full} ? 'getSupergroupFullInfo' : 'getSupergroup',
                  supergroup_id => _supergroup_id($id) }, $cb);
    return;
}

sub basic_group {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('basic_group_id', $id);
    $self->send({ '@type' => $opt{full} ? 'getBasicGroupFullInfo' : 'getBasicGroup',
                  basic_group_id => 0 + $id }, $cb);
    return;
}

my %SUPERGROUP_FILTER = (
    recent         => 'supergroupMembersFilterRecent',
    contacts       => 'supergroupMembersFilterContacts',
    administrators => 'supergroupMembersFilterAdministrators',
    restricted     => 'supergroupMembersFilterRestricted',
    banned         => 'supergroupMembersFilterBanned',
    bots           => 'supergroupMembersFilterBots',
);

sub supergroup_members {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('supergroup_id', $id);
    my %req = ('@type' => 'getSupergroupMembers',
               supergroup_id => _supergroup_id($id),
               offset => 0 + ($opt{offset} // 0),
               limit  => 0 + ($opt{limit} // 200));
    if (defined $opt{filter}) {
        my $t = $SUPERGROUP_FILTER{ $opt{filter} }
            or croak "unknown supergroup member filter '$opt{filter}'";
        $req{filter} = { '@type' => $t };
    }
    $self->send(\%req, $cb);
    return;
}

sub groups_in_common {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    my %opt = @rest;
    _need('user_id', $user_id);
    $self->send({ '@type' => 'getGroupsInCommon', user_id => 0 + $user_id,
                  offset_chat_id => 0 + ($opt{offset_chat_id} // 0),
                  limit => 0 + ($opt{limit} // 100) }, $cb);
    return;
}

sub chat_event_log {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({
        '@type'        => 'getChatEventLog',
        chat_id        => 0 + $chat_id,
        query          => $opt{query} // '',
        from_event_id  => "" . ($opt{from_event_id} // 0),
        limit          => 0 + ($opt{limit} // 100),
        user_ids       => [ map { 0 + $_ } @{ $opt{users} || [] } ],
    }, $cb);
    return;
}

sub chat_statistics {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'getChatStatistics', chat_id => 0 + $chat_id,
                  is_dark => _json_bool($opt{dark}) }, $cb);
    return;
}

sub pinned_message {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'getChatPinnedMessage', chat_id => 0 + $chat_id }, $cb);
    return;
}

sub clear_action_bar {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'removeChatActionBar', chat_id => 0 + $chat_id }, $cb);
    return;
}

# which identities may post here, and which one to post as: a channel admin
# can speak as the channel rather than as themselves
sub message_senders {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'getChatAvailableMessageSenders',
                  chat_id => 0 + $chat_id }, $cb);
    return;
}

sub set_message_sender {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $sender_id, @rest) = @args;
    _need('chat_id, sender_id', $chat_id, $sender_id);
    # a negative id is a chat posting as itself, a positive one is a user
    my $sender = $sender_id < 0
        ? { '@type' => 'messageSenderChat', chat_id => 0 + $sender_id }
        : _sender($sender_id);
    $self->send({ '@type' => 'setChatMessageSender', chat_id => 0 + $chat_id,
                  message_sender_id => $sender }, $cb);
    return;
}


my %TOP_CATEGORY = (
    users        => 'topChatCategoryUsers',
    bots         => 'topChatCategoryBots',
    groups       => 'topChatCategoryGroups',
    channels     => 'topChatCategoryChannels',
    inline_bots  => 'topChatCategoryInlineBots',
    calls        => 'topChatCategoryCalls',
    forwards     => 'topChatCategoryForwardChats',
);

# searches chats this account knows; search_public_chats reaches the directory
sub search_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query, @rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'searchChats',
                  query => defined $query ? "$query" : '',
                  limit => 0 + ($opt{limit} // 50) }, $cb);
    return;
}

sub search_public_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query, @rest) = @args;
    _need('query', $query);
    $self->send({ '@type' => 'searchPublicChats', query => "$query" }, $cb);
    return;
}

sub top_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($category, @rest) = @args;
    my %opt = @rest;
    my $t = $TOP_CATEGORY{ $category // 'users' }
        or croak "unknown top chat category '" . ($category // '') . "'";
    $self->send({ '@type' => 'getTopChats', category => { '@type' => $t },
                  limit => 0 + ($opt{limit} // 30) }, $cb);
    return;
}

sub recommended_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getRecommendedChats' }, $cb);
    return;
}

sub recently_opened_chats {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'getRecentlyOpenedChats',
                  limit => 0 + ($opt{limit} // 30) }, $cb);
    return;
}

sub check_chat_username {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $username, @rest) = @args;
    _need('chat_id, username', $chat_id, $username);
    $self->send({ '@type' => 'checkChatUsername', chat_id => 0 + $chat_id,
                  username => "$username" }, $cb);
    return;
}

sub report_chat {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'reportChat', chat_id => 0 + $chat_id,
                  option_id => $opt{option_id} // '',
                  message_ids => [ map { 0 + $_ } @{ $opt{messages} || [] } ],
                  text => $opt{text} // '' }, $cb);
    return;
}

sub default_disable_notification {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $on, @rest) = @args;
    _need('chat_id', $chat_id);
    $self->send({ '@type' => 'toggleChatDefaultDisableNotification',
                  chat_id => 0 + $chat_id,
                  default_disable_notification =>
                      _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

1;
