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
    api_id => 1, api_hash => 'x', database_directory => 't/tmp-forum');

# --- topics
$td->create_topic(-100, 'Support', sub {});
my $r = last_req();
is $r->{'@type'}, 'createForumTopic', 'create_topic sends createForumTopic';
is $r->{chat_id}, -100, 'chat id passed through';
is $r->{name}, 'Support', 'name passed through';
ok !exists $r->{icon}, 'no icon is sent when none was asked for';

$td->create_topic(-100, 'Bugs', color => 0x6FB9F0, custom_emoji_id => '5312536423851630001', sub {});
$r = last_req();
is $r->{icon}{'@type'}, 'forumTopicIcon', 'an icon is built when asked for';
is $r->{icon}{color}, 0x6FB9F0, 'icon colour passed through';
like last_json(), qr/"custom_emoji_id":"5312536423851630001"/,
    'custom emoji id crosses as a JSON string';

$td->edit_topic(-100, 55, name => 'Renamed', sub {});
$r = last_req();
is $r->{'@type'}, 'editForumTopic', 'edit_topic sends editForumTopic';
is $r->{forum_topic_id}, 55, 'topic id passed through';
is $r->{name}, 'Renamed', 'new name passed through';
like last_json(), qr/"edit_icon_custom_emoji":false/,
    'the icon is left alone when no emoji was given';

$td->edit_topic(-100, 55, custom_emoji_id => 7, sub {});
like last_json(), qr/"edit_icon_custom_emoji":true/,
    'and edited when one was';

$td->topic(-100, 55, sub {});
is last_req()->{'@type'}, 'getForumTopic', 'topic sends getForumTopic';

$td->topics(-100, limit => 20, sub {});
$r = last_req();
is $r->{'@type'}, 'getForumTopics', 'topics sends getForumTopics';
is $r->{limit}, 20, 'limit passed through';

$td->topic_history(-100, 55, limit => 10, sub {});
$r = last_req();
is $r->{'@type'}, 'getForumTopicHistory', 'topic_history sends its method';
is $r->{limit}, 10, 'limit passed through';

$td->topic_link(-100, 55, sub {});
is last_req()->{'@type'}, 'getForumTopicLink', 'topic_link sends its method';

$td->close_topic(-100, 55, sub {});
$r = last_req();
is $r->{'@type'}, 'toggleForumTopicIsClosed', 'close_topic sends its method';
like last_json(), qr/"is_closed":true/, 'closing defaults to true';
$td->close_topic(-100, 55, 0, sub {});
like last_json(), qr/"is_closed":false/, 'and can reopen';

$td->pin_topic(-100, 55, sub {});
like last_json(), qr/"is_pinned":true/, 'pin_topic defaults to pinning';

$td->unpin_topic_messages(-100, 55, sub {});
is last_req()->{'@type'}, 'unpinAllForumTopicMessages', 'unpin_topic_messages sends its method';

$td->hide_general_topic(-100, 1, sub {});
$r = last_req();
is $r->{'@type'}, 'toggleGeneralForumTopicIsHidden', 'hide_general_topic sends its method';
ok !exists $r->{forum_topic_id}, 'the general topic takes no topic id';

$td->topic_icons(sub {});
is last_req()->{'@type'}, 'getForumTopicDefaultIcons', 'topic_icons sends its method';

$td->delete_topic(-100, 55, sub {});
is last_req()->{'@type'}, 'deleteForumTopic', 'delete_topic sends deleteForumTopic';

$err = do { local $@; eval { $td->create_topic(-100, undef, sub {}) }; $@ };
like $err, qr/required/, 'a missing topic name is refused';

# --- topic-aware and scheduled sending
$td->send_message(-100, 'in a topic', topic => 55, sub {});
$r = last_req();
is $r->{topic_id}{'@type'}, 'messageTopicForum', 'send_message targets a forum topic';
is $r->{topic_id}{forum_topic_id}, 55, 'with the topic id';

$td->send_message(-100, 'plain', sub {});
ok !exists last_req()->{topic_id}, 'and omits topic_id when none was given';

$td->send_message(-100, 'later', schedule => 1800000000, sub {});
$r = last_req();
is $r->{options}{scheduling_state}{'@type'}, 'messageSchedulingStateSendAtDate',
    'schedule sets a scheduling state';
is $r->{options}{scheduling_state}{send_date}, 1800000000, 'with the send date';

# silent and schedule share the options object; neither may drop the other
$td->send_message(-100, 'quiet and later', schedule => 1800000000, silent => 1, sub {});
$r = last_req();
is $r->{options}{scheduling_state}{send_date}, 1800000000, 'schedule survives silent';
like last_json(), qr/"disable_notification":true/, 'silent survives schedule';

$td->send_message(-100, 'quiet', silent => 1, sub {});
ok !exists last_req()->{options}{scheduling_state},
    'silent alone sets no scheduling state';

# a scheduled message is not delivered now, so waiting for delivery would hang
$err = do { local $@;
    eval { $td->send_message(-100, 'x', schedule => 1800000000, wait => 'sent', sub {}) };
    $@ };
like $err, qr/schedule/, 'wait => sent with schedule is refused';

$td->scheduled(-100, sub {});
is last_req()->{'@type'}, 'getChatScheduledMessages', 'scheduled sends its method';

done_testing;
