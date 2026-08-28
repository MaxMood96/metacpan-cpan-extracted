use strict;
use warnings;
use Test::More;

BEGIN { $ENV{EV_TDLIB_SHUTDOWN_TIMEOUT} = 0.1 }

use EV;
use EV::Telegram::TDLib;
use Cpanel::JSON::XS;

my @sent;
{
    no warnings 'redefine';
    *EV::Telegram::TDLib::_send = sub { push @sent, $_[1] };
}
sub last_json { $sent[-1] }
sub last_req  { Cpanel::JSON::XS->new->decode($sent[-1]) }

my $err;
my $td = EV::Telegram::TDLib->new(
    api_id => 1, api_hash => 'x', database_directory => 't/tmp-chatmgmt');

# --- a supergroup chat id is -1000000000000 minus the supergroup id, and the
# supergroup_* methods want the latter; passing the chat id must still work
$td->make_forum(-1000000001234, sub {});
my $r = last_req();
is $r->{'@type'}, 'toggleSupergroupIsForum', 'make_forum sends its method';
is $r->{supergroup_id}, 1234, 'a chat id is converted to a supergroup id';
like last_json(), qr/"is_forum":true/, 'and defaults to making it a forum';

$td->make_forum(1234, sub {});
is last_req()->{supergroup_id}, 1234, 'a supergroup id is passed through unchanged';

$td->make_forum(-1000000001234, 0, sub {});
like last_json(), qr/"is_forum":false/, 'and it can be turned off';

for my $t ([ sign_messages => 'toggleSupergroupSignMessages' ],
           [ join_to_send  => 'toggleSupergroupJoinToSendMessages' ],
           [ all_history_available => 'toggleSupergroupIsAllHistoryAvailable' ],
           [ hide_members  => 'toggleSupergroupHasHiddenMembers' ]) {
    my ($m, $type) = @$t;
    $td->$m(-1000000005678, sub {});
    $r = last_req();
    is $r->{'@type'}, $type, "$m sends $type";
    is $r->{supergroup_id}, 5678, "$m converts the chat id";
}

$td->join_by_request(-1000000005678, 1, guard_bot => 42, sub {});
$r = last_req();
is $r->{'@type'}, 'toggleSupergroupJoinByRequest', 'join_by_request works';
is $r->{guard_bot_user_id}, 42, 'the guard bot passed through';

$td->set_supergroup_username(-1000000005678, 'mygroup', sub {});
is last_req()->{username}, 'mygroup', 'set_supergroup_username works';

# --- membership
$td->add_members(-100, [1, 2], sub {});
$r = last_req();
is $r->{'@type'}, 'addChatMembers', 'add_members sends addChatMembers';
is_deeply $r->{user_ids}, [1, 2], 'user ids passed through';

$err = do { local $@; eval { $td->add_members(-100, 5, sub {}) }; $@ };
like $err, qr/arrayref/, 'a non-arrayref member list is refused';

$td->ban_member(-100, 42, revoke => 1, sub {});
$r = last_req();
is $r->{'@type'}, 'banChatMember', 'ban_member sends banChatMember';
is $r->{member_id}{'@type'}, 'messageSenderUser', 'the member is a message sender';
like last_json(), qr/"revoke_messages":true/, 'revoking their messages is a JSON boolean';

$td->transfer_ownership(-100, 42, 'hunter2', sub {});
$r = last_req();
is $r->{'@type'}, 'transferChatOwnership', 'transfer_ownership works';
is $r->{password}, 'hunter2', 'the password is required and passed through';

$td->set_default_admin_rights({ '@type' => 'chatAdministratorRights' }, sub {});
is last_req()->{'@type'}, 'setDefaultGroupAdministratorRights',
    'default admin rights go to groups';
$td->set_default_admin_rights({ '@type' => 'chatAdministratorRights' }, channel => 1, sub {});
is last_req()->{'@type'}, 'setDefaultChannelAdministratorRights',
    'and to channels when asked';

# --- creating and destroying
$td->create_group('My channel', channel => 1, sub {});
$r = last_req();
is $r->{'@type'}, 'createNewSupergroupChat', 'create_group makes a supergroup by default';
like last_json(), qr/"is_channel":true/, 'and can make a channel';

$td->create_group('My forum', forum => 1, sub {});
like last_json(), qr/"is_forum":true/, 'or a forum';

# members up front means a basic group, which is a different call
$td->create_group('Small group', members => [1, 2], sub {});
$r = last_req();
is $r->{'@type'}, 'createNewBasicGroupChat', 'members up front makes a basic group';
is_deeply $r->{user_ids}, [1, 2], 'with those members';

$td->upgrade_to_supergroup(-100, sub {});
is last_req()->{'@type'}, 'upgradeBasicGroupChatToSupergroupChat', 'upgrade works';

$td->delete_chat(-100, sub {});
is last_req()->{'@type'}, 'deleteChat', 'delete_chat works';

$td->delete_history(-100, revoke => 1, sub {});
$r = last_req();
is $r->{'@type'}, 'deleteChatHistory', 'delete_history works';
like last_json(), qr/"revoke":true/, 'and can revoke for everyone';

$td->set_slow_mode(-100, 30, sub {});
is last_req()->{slow_mode_delay}, 30, 'set_slow_mode works';
$td->set_auto_delete(-100, 86400, sub {});
is last_req()->{message_auto_delete_time}, 86400, 'set_auto_delete works';
$td->set_discussion_group(-100, -200, sub {});
is last_req()->{discussion_chat_id}, -200, 'set_discussion_group works';
$td->protect_content(-100, sub {});
like last_json(), qr/"has_protected_content":true/, 'protect_content defaults to on';

# --- info and state
$td->fetch_chat(-100, sub {});
is last_req()->{'@type'}, 'getChat', 'fetch_chat asks TDLib rather than the cache';
$td->close_chat(-100, sub {});
is last_req()->{'@type'}, 'closeChat', 'close_chat works';
$td->user_full_info(42, sub {});
is last_req()->{'@type'}, 'getUserFullInfo', 'user_full_info works';

$td->supergroup(-1000000005678, sub {});
$r = last_req();
is $r->{'@type'}, 'getSupergroup', 'supergroup asks for the short record';
is $r->{supergroup_id}, 5678, 'converting the chat id';
$td->supergroup(-1000000005678, full => 1, sub {});
is last_req()->{'@type'}, 'getSupergroupFullInfo', 'and the full one when asked';

$td->basic_group(9, full => 1, sub {});
is last_req()->{'@type'}, 'getBasicGroupFullInfo', 'basic_group full form works';

$td->supergroup_members(-1000000005678, filter => 'bots', sub {});
$r = last_req();
is $r->{'@type'}, 'getSupergroupMembers', 'supergroup_members works';
is $r->{filter}{'@type'}, 'supergroupMembersFilterBots', 'the filter is typed';

$err = do { local $@;
    eval { $td->supergroup_members(-1000000005678, filter => 'ghosts', sub {}) }; $@ };
like $err, qr/unknown supergroup member filter/, 'an unknown filter is refused';

$td->groups_in_common(42, sub {});
is last_req()->{'@type'}, 'getGroupsInCommon', 'groups_in_common works';

# from_event_id is int64
$td->chat_event_log(-100, from_event_id => '7239857203948572039', sub {});
$r = last_req();
is $r->{'@type'}, 'getChatEventLog', 'chat_event_log works';
like last_json(), qr/"from_event_id":"7239857203948572039"/,
    'the event id crosses as a JSON string';

$td->chat_statistics(-100, sub {});
is last_req()->{'@type'}, 'getChatStatistics', 'chat_statistics works';
$td->pinned_message(-100, sub {});
is last_req()->{'@type'}, 'getChatPinnedMessage', 'pinned_message works';
$td->clear_action_bar(-100, sub {});
is last_req()->{'@type'}, 'removeChatActionBar', 'clear_action_bar works';
$td->message_senders(-100, sub {});
is last_req()->{'@type'}, 'getChatAvailableMessageSenders', 'message_senders works';

# a negative sender id means posting as a chat, a positive one as a user
$td->set_message_sender(-100, -200, sub {});
is last_req()->{message_sender_id}{'@type'}, 'messageSenderChat',
    'a negative sender id posts as a chat';
$td->set_message_sender(-100, 42, sub {});
is last_req()->{message_sender_id}{'@type'}, 'messageSenderUser',
    'a positive one posts as a user';

done_testing;
