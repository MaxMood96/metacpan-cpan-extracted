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
    api_id => 1, api_hash => 'x', database_directory => 't/tmp-folders');

# the name is a chatFolderName wrapping a formattedText, not a plain string
$td->create_folder({ name => 'Work', included_chat_ids => [-100, -200] }, sub {});
my $r = last_req();
is $r->{'@type'}, 'createChatFolder', 'create_folder sends createChatFolder';
is $r->{folder}{'@type'}, 'chatFolder', 'a chatFolder is built';
is $r->{folder}{name}{'@type'}, 'chatFolderName', 'the name is a chatFolderName';
is $r->{folder}{name}{text}{'@type'}, 'formattedText', 'wrapping a formattedText';
is $r->{folder}{name}{text}{text}, 'Work', 'with the name in it';
is_deeply $r->{folder}{included_chat_ids}, [-100, -200], 'included chats passed through';
is_deeply $r->{folder}{excluded_chat_ids}, [], 'absent lists are empty, not missing';
like last_json(), qr/"include_bots":false/, 'flags are JSON booleans';

$td->create_folder({ name => 'Fun', icon => 'Party', include_groups => 1 }, sub {});
$r = last_req();
is $r->{folder}{icon}{'@type'}, 'chatFolderIcon', 'an icon is built when named';
is $r->{folder}{icon}{name}, 'Party', 'with that icon name';
like last_json(), qr/"include_groups":true/, 'a set flag is true';

$td->create_folder({ name => 'Plain' }, sub {});
ok !exists last_req()->{folder}{icon}, 'no icon is sent when none was named';

$err = do { local $@; eval { $td->create_folder({ }, sub {}) }; $@ };
like $err, qr/needs a name/, 'a folder without a name is refused';
$err = do { local $@; eval { $td->create_folder('Work', sub {}) }; $@ };
like $err, qr/hashref/, 'a non-hashref folder is refused';

$td->folder(3, sub {});
$r = last_req();
is $r->{'@type'}, 'getChatFolder', 'folder sends getChatFolder';
is $r->{chat_folder_id}, 3, 'folder id passed through';

$td->edit_folder(3, { name => 'Renamed' }, sub {});
$r = last_req();
is $r->{'@type'}, 'editChatFolder', 'edit_folder sends editChatFolder';
is $r->{folder}{name}{text}{text}, 'Renamed', 'with the new name';

$td->delete_folder(3, leave_chats => [-100], sub {});
$r = last_req();
is $r->{'@type'}, 'deleteChatFolder', 'delete_folder sends deleteChatFolder';
is_deeply $r->{leave_chat_ids}, [-100], 'chats to leave passed through';

$td->delete_folder(3, sub {});
is_deeply last_req()->{leave_chat_ids}, [], 'and defaults to leaving none';

$td->reorder_folders([3, 1, 2], main_position => 1, sub {});
$r = last_req();
is $r->{'@type'}, 'reorderChatFolders', 'reorder_folders sends its method';
is_deeply $r->{chat_folder_ids}, [3, 1, 2], 'the order passed through';
is $r->{main_chat_list_position}, 1, 'main list position passed through';

$err = do { local $@; eval { $td->reorder_folders(3, sub {}) }; $@ };
like $err, qr/arrayref/, 'a non-arrayref order is refused';

$td->recommended_folders(sub {});
is last_req()->{'@type'}, 'getRecommendedChatFolders', 'recommended_folders works';

$td->folder_chat_count({ name => 'Work', include_bots => 1 }, sub {});
$r = last_req();
is $r->{'@type'}, 'getChatFolderChatCount', 'folder_chat_count sends its method';
is $r->{folder}{'@type'}, 'chatFolder', 'and takes a whole folder';

$td->folder_tags(1, sub {});
$r = last_req();
is $r->{'@type'}, 'toggleChatFolderTags', 'folder_tags sends its method';
like last_json(), qr/"are_tags_enabled":true/, 'the flag is a JSON boolean';

# --- folder invite links
$td->folder_invite_link(3, name => 'share', chats => [-100], sub {});
$r = last_req();
is $r->{'@type'}, 'createChatFolderInviteLink', 'folder_invite_link sends its method';
is $r->{name}, 'share', 'link name passed through';
is_deeply $r->{chat_ids}, [-100], 'shared chats passed through';

$td->folder_invite_links(3, sub {});
is last_req()->{'@type'}, 'getChatFolderInviteLinks', 'folder_invite_links works';

$td->edit_folder_invite_link(3, 'https://t.me/addlist/x', name => 'e', sub {});
$r = last_req();
is $r->{'@type'}, 'editChatFolderInviteLink', 'edit_folder_invite_link works';
is $r->{invite_link}, 'https://t.me/addlist/x', 'the link passed through';

$td->delete_folder_invite_link(3, 'https://t.me/addlist/x', sub {});
is last_req()->{'@type'}, 'deleteChatFolderInviteLink', 'delete_folder_invite_link works';

# these two take only the link, like the chat invite equivalents
$td->check_folder_invite_link('https://t.me/addlist/x', sub {});
$r = last_req();
is $r->{'@type'}, 'checkChatFolderInviteLink', 'check_folder_invite_link works';
ok !exists $r->{chat_folder_id}, 'and sends no folder id';

$td->add_folder_by_link('https://t.me/addlist/x', chats => [-100], sub {});
$r = last_req();
is $r->{'@type'}, 'addChatFolderByInviteLink', 'add_folder_by_link works';
is_deeply $r->{chat_ids}, [-100], 'chosen chats passed through';

$err = do { local $@; eval { $td->folder(undef, sub {}) }; $@ };
like $err, qr/required/, 'a missing folder id is refused';

done_testing;
