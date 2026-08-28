package EV::Telegram::TDLib::Bots;

use strict;
use warnings;
use Carp qw(croak);
use MIME::Base64 ();

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES = (
    updateNewCallbackQuery => \&_update_callback_query,
    updateNewInlineQuery  => \&_update_inline_query,
);

# TL `bytes` travels base64-encoded over the JSON interface, so callback
# payloads are decoded on the way in and encoded on the way out; a caller
# that never sees the encoding cannot get it wrong
sub _update_callback_query {
    my ($self, $obj) = @_;
    my $cb = $self->{on_callback_query} or return;
    my $payload = $obj->{payload} // {};
    my %q = (
        id             => $obj->{id},
        sender_user_id => $obj->{sender_user_id},
        chat_id        => $obj->{chat_id},
        message_id     => $obj->{message_id},
        type           => $payload->{'@type'},
    );
    $q{data} = MIME::Base64::decode_base64($payload->{data})
        if defined $payload->{data};
    $q{game_short_name} = $payload->{game_short_name}
        if defined $payload->{game_short_name};
    $self->_guarded($cb, \%q);
}

sub on_callback_query {
    my ($self, $cb) = @_;
    $self->{on_callback_query} = $cb if $cb;
    return $self->{on_callback_query};
}

sub answer_callback_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    # int64 crosses the JSON interface as a string; a number would lose
    # precision on ids above 2^53
    $self->send({
        '@type'           => 'answerCallbackQuery',
        callback_query_id => "$id",
        text              => $opt{text} // '',
        show_alert        => _json_bool($opt{show_alert}),
        url               => $opt{url} // '',
        cache_time        => 0 + ($opt{cache_time} // 0),
    }, $cb);
    return;
}

# rows: [ [ { text => 'Yes', data => 'yes' }, { text => 'Docs', url => '...' } ] ]
sub inline_keyboard {
    my ($self, $rows) = @_;
    croak 'inline_keyboard needs an arrayref of rows'
        unless ref $rows eq 'ARRAY';
    my @out;
    for my $row (@$rows) {
        croak 'each keyboard row must be an arrayref' unless ref $row eq 'ARRAY';
        my @buttons;
        for my $b (@$row) {
            croak 'each button needs a text' unless defined $b->{text};
            my $type = defined $b->{data}
                ? { '@type' => 'inlineKeyboardButtonTypeCallback',
                    data => MIME::Base64::encode_base64($b->{data}, '') }
                : defined $b->{url}
                ? { '@type' => 'inlineKeyboardButtonTypeUrl', url => $b->{url} }
                : defined $b->{web_app}
                ? { '@type' => 'inlineKeyboardButtonTypeWebApp', url => $b->{web_app} }
                : croak 'each button needs data, url or web_app';
            push @buttons, { '@type' => 'inlineKeyboardButton',
                             text => "$b->{text}", type => $type };
        }
        push @out, \@buttons;
    }
    return { '@type' => 'replyMarkupInlineKeyboard', rows => \@out };
}

# a restrict_X flag means "X must match"; deriving it from whether the
# caller mentioned the key keeps both halves from drifting apart
sub _request_chat_type {
    my ($s) = @_;
    croak 'request_chat needs a hashref' unless ref $s eq 'HASH';
    return {
        '@type'                    => 'keyboardButtonTypeRequestChat',
        id                         => 0 + ($s->{id} // 0),
        chat_is_channel            => _json_bool($s->{channel}),
        restrict_chat_is_forum     => _json_bool(exists $s->{forum}),
        chat_is_forum              => _json_bool($s->{forum}),
        restrict_chat_has_username => _json_bool(exists $s->{username}),
        chat_has_username          => _json_bool($s->{username}),
        chat_is_created            => _json_bool($s->{created}),
        bot_is_member              => _json_bool($s->{bot_is_member}),
        request_title              => _json_bool($s->{want_title}),
        request_username           => _json_bool($s->{want_username}),
        request_photo              => _json_bool($s->{want_photo}),
        (defined $s->{user_rights} ? (user_administrator_rights => $s->{user_rights}) : ()),
        (defined $s->{bot_rights}  ? (bot_administrator_rights  => $s->{bot_rights})  : ()),
    };
}

sub _request_users_type {
    my ($s) = @_;
    croak 'request_users needs a hashref' unless ref $s eq 'HASH';
    return {
        '@type'                  => 'keyboardButtonTypeRequestUsers',
        id                       => 0 + ($s->{id} // 0),
        restrict_user_is_bot     => _json_bool(exists $s->{bot}),
        user_is_bot              => _json_bool($s->{bot}),
        restrict_user_is_premium => _json_bool(exists $s->{premium}),
        user_is_premium          => _json_bool($s->{premium}),
        max_quantity             => 0 + ($s->{max} // 1),
        request_name             => _json_bool($s->{want_name}),
        request_username         => _json_bool($s->{want_username}),
        request_photo            => _json_bool($s->{want_photo}),
    };
}

# rows: [ [ 'Yes', { text => 'Share number', request => 'phone' } ], ... ]
sub reply_keyboard {
    my ($self, $rows, %opt) = @_;
    croak 'reply_keyboard needs an arrayref of rows' unless ref $rows eq 'ARRAY';
    my @out;
    for my $row (@$rows) {
        croak 'each keyboard row must be an arrayref' unless ref $row eq 'ARRAY';
        push @out, [ map {
            my $b = ref $_ eq 'HASH' ? $_ : { text => $_ };
            croak 'each button needs a text' unless defined $b->{text};
            my $type = defined $b->{web_app}
                ? { '@type' => 'keyboardButtonTypeWebApp', url => $b->{web_app} }
                : defined $b->{request_chat}  ? _request_chat_type($b->{request_chat})
                : defined $b->{request_users} ? _request_users_type($b->{request_users})
                : { '@type' =>
                      !defined $b->{request}      ? 'keyboardButtonTypeText'
                    : $b->{request} eq 'phone'    ? 'keyboardButtonTypeRequestPhoneNumber'
                    : $b->{request} eq 'location' ? 'keyboardButtonTypeRequestLocation'
                    : croak "unknown button request '$b->{request}'" };
            +{ '@type' => 'keyboardButton', text => "$b->{text}", type => $type };
        } @$row ];
    }
    return {
        '@type'         => 'replyMarkupShowKeyboard',
        rows            => \@out,
        resize_keyboard => _json_bool(exists $opt{resize} ? $opt{resize} : 1),
        one_time        => _json_bool($opt{one_time}),
        is_persistent   => _json_bool($opt{persistent}),
        (defined $opt{placeholder}
            ? (input_field_placeholder => "$opt{placeholder}") : ()),
    };
}

sub remove_keyboard {
    my ($self, %opt) = @_;
    return { '@type' => 'replyMarkupRemoveKeyboard',
             is_personal => _json_bool($opt{personal}) };
}

# the "/" menu a bot offers; an empty list clears it
sub set_commands {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($commands, @rest) = @args;
    my %opt = @rest;
    croak 'set_commands needs an arrayref' unless ref $commands eq 'ARRAY';
    my @cmds;
    for my $c (@$commands) {
        my ($name, $desc) = ref $c eq 'ARRAY' ? @$c
                          : ref $c eq 'HASH'  ? @{$c}{qw(command description)}
                          : croak 'each command must be an arrayref or hashref';
        croak 'each command needs a name and a description'
            unless defined $name && defined $desc;
        $name =~ s{^/}{};
        push @cmds, { '@type' => 'botCommand',
                      command => "$name", description => "$desc" };
    }
    $self->send({
        '@type'        => 'setCommands',
        scope          => $opt{scope} // { '@type' => 'botCommandScopeDefault' },
        language_code  => $opt{language_code} // '',
        commands       => \@cmds,
    }, $cb);
    return;
}

# TDLib addresses a bot's own profile by its user id, which for a bot session
# is the account's own id; my_id comes from updateOption, so the common case
# needs no getMe first
sub _bot_id {
    my ($self, $opt) = @_;
    my $id = $opt->{bot_user_id} // $self->my_id;
    croak 'bot_user_id is not known yet: pass it, or wait for login'
        unless $id;
    return 0 + $id;
}

sub set_bot_name {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($name, @rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'        => 'setBotName',
        bot_user_id    => $self->_bot_id(\%opt),
        language_code  => $opt{language_code} // '',
        name           => defined $name ? "$name" : '',
    }, $cb);
    return;
}

sub set_bot_description {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($text, @rest) = @args;
    my %opt = @rest;
    # the long text, shown on the bot's empty chat screen
    $self->send({
        '@type'        => 'setBotInfoDescription',
        bot_user_id    => $self->_bot_id(\%opt),
        language_code  => $opt{language_code} // '',
        description    => defined $text ? "$text" : '',
    }, $cb);
    return;
}

sub set_bot_short_description {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($text, @rest) = @args;
    my %opt = @rest;
    # the one-liner shown in the bot's profile and in search results
    $self->send({
        '@type'            => 'setBotInfoShortDescription',
        bot_user_id        => $self->_bot_id(\%opt),
        language_code      => $opt{language_code} // '',
        short_description  => defined $text ? "$text" : '',
    }, $cb);
    return;
}

sub set_bot_photo {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($path, @rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'      => 'setBotProfilePhoto',
        bot_user_id  => $self->_bot_id(\%opt),
        photo        => $self->_input_chat_photo($path, \%opt),
    }, $cb);
    return;
}

sub _update_inline_query {
    my ($self, $obj) = @_;
    my $cb = $self->{on_inline_query} or return;
    $self->_guarded($cb, {
        id             => $obj->{id},
        sender_user_id => $obj->{sender_user_id},
        query          => $obj->{query},
        offset         => $obj->{offset},
        chat_type      => $obj->{chat_type}{'@type'},
    });
}

sub on_inline_query {
    my ($self, $cb) = @_;
    $self->{on_inline_query} = $cb if $cb;
    return $self->{on_inline_query};
}

# results: [ { id => '1', title => 'A', message => 'sent when picked' }, ... ]
sub answer_inline_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $results, @rest) = @args;
    my %opt = @rest;
    croak 'answer_inline_query needs an arrayref of results'
        unless ref $results eq 'ARRAY';
    my $n = 0;
    my @out;
    my $bad;
    for my $r (@$results) {
        croak 'each result needs a title' unless defined $r->{title};
        my $text = defined $r->{message} ? $r->{message} : $r->{title};
        push @out, {
            '@type'      => 'inputInlineQueryResultArticle',
            id           => defined $r->{id} ? "$r->{id}" : "" . ++$n,
            title        => "$r->{title}",
            description  => defined $r->{description} ? "$r->{description}" : '',
            url          => $r->{url} // '',
            thumbnail_url    => $r->{thumbnail_url} // '',
            thumbnail_width  => 0 + ($r->{thumbnail_width} // 0),
            thumbnail_height => 0 + ($r->{thumbnail_height} // 0),
            input_message_content => {
                '@type' => 'inputMessageText',
                text    => do {
                    my $t = $self->_format_text($text,
                        $r->{parse_mode} // $opt{parse_mode});
                    # a parse failure must reach the caller, not TDLib
                    $bad ||= $t if ($t->{'@type'} // '') eq 'error';
                    $t;
                },
            },
            ($r->{reply_markup} ? (reply_markup => $r->{reply_markup}) : ()),
        };
    }
    if ($bad) { $cb->(undef, $bad); return }
    $self->send({
        '@type'           => 'answerInlineQuery',
        # int64 over the JSON interface: a number would lose precision
        inline_query_id   => "$id",
        is_personal       => _json_bool($opt{personal}),
        results           => \@out,
        cache_time        => 0 + ($opt{cache_time} // 300),
        next_offset       => $opt{next_offset} // '',
    }, $cb);
    return;
}

sub commands {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'getCommands',
                  scope => $opt{scope} // { '@type' => 'botCommandScopeDefault' },
                  language_code => $opt{language_code} // '' }, $cb);
    return;
}

sub delete_commands {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'deleteCommands',
                  scope => $opt{scope} // { '@type' => 'botCommandScopeDefault' },
                  language_code => $opt{language_code} // '' }, $cb);
    return;
}

for my $spec ([ bot_name              => 'getBotName' ],
              [ bot_description       => 'getBotInfoDescription' ],
              [ bot_short_description => 'getBotInfoShortDescription' ]) {
    my ($name, $type) = @$spec;
    no strict 'refs';
    *{$name} = sub {
        my ($self, @args) = @_;
        my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
        my (@rest) = @args;
        my %opt = @rest;
        $self->send({ '@type' => $type, bot_user_id => $self->_bot_id(\%opt),
                      language_code => $opt{language_code} // '' }, $cb);
        return;
    };
}

# these address a message by inline_message_id, which is what an inline
# query result carries; edit_message_* take a (chat_id, message_id) pair
sub edit_inline_text {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $text, @rest) = @args;
    my %opt = @rest;
    _need('inline_message_id, text', $id, $text);
    my $content = $self->_input_text($text, \%opt, $cb) or return;
    $self->send({ '@type' => 'editInlineMessageText', inline_message_id => "$id",
                  reply_markup => $opt{reply_markup},
                  input_message_content => $content }, $cb);
    return;
}

sub edit_inline_caption {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $caption, @rest) = @args;
    my %opt = @rest;
    _need('inline_message_id, caption', $id, $caption);
    my $formatted = $self->_format_text($caption, $opt{parse_mode});
    return $cb->(undef, $formatted) if ($formatted->{'@type'} // '') eq 'error';
    $self->send({ '@type' => 'editInlineMessageCaption', inline_message_id => "$id",
                  reply_markup => $opt{reply_markup}, caption => $formatted }, $cb);
    return;
}

sub edit_inline_media {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $content, @rest) = @args;
    my %opt = @rest;
    _need('inline_message_id, content', $id, $content);
    $self->send({ '@type' => 'editInlineMessageMedia', inline_message_id => "$id",
                  reply_markup => $opt{reply_markup},
                  input_message_content => $content }, $cb);
    return;
}

sub edit_inline_markup {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $markup, @rest) = @args;
    _need('inline_message_id, reply_markup', $id, $markup);
    $self->send({ '@type' => 'editInlineMessageReplyMarkup',
                  inline_message_id => "$id", reply_markup => $markup }, $cb);
    return;
}

# live_period and friends belong to the liveLocation wrapper; at top level
# TDLib drops them and the location silently never expires
sub edit_inline_location {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $location, @rest) = @args;
    my %opt = @rest;
    _need('inline_message_id', $id);
    $self->send({
        '@type'            => 'editInlineMessageLiveLocation',
        inline_message_id  => "$id",
        reply_markup       => $opt{reply_markup},
        location           => {
            '@type'                => 'liveLocation',
            location               => $location,
            live_period            => 0 + ($opt{live_period} // 0),
            heading                => 0 + ($opt{heading} // 0),
            proximity_alert_radius => 0 + ($opt{proximity_alert_radius} // 0),
        },
    }, $cb);
    return;
}

# the user side of an inline keyboard: presses a button on someone else's
# message, the way a client answers a bot's prompt
sub press {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $message_id, $data, @rest) = @args;
    _need('chat_id, message_id, data', $chat, $message_id, $data);
    $self->send({ '@type' => 'getCallbackQueryAnswer',
                  chat_id => 0 + $chat, message_id => 0 + $message_id,
                  payload => { '@type' => 'callbackQueryPayloadData',
                               data => MIME::Base64::encode_base64($data, '') } }, $cb);
    return;
}

sub inline_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $query, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id, query', $bot, $query);
    $self->send({ '@type' => 'getInlineQueryResults', bot_user_id => 0 + $bot,
                  chat_id => 0 + ($opt{chat_id} // 0),
                  user_location => $opt{location},
                  query => "$query", offset => $opt{offset} // '' }, $cb);
    return;
}

sub send_inline_result {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $query_id, $result_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, query_id, result_id', $chat, $query_id, $result_id);
    $self->send({ '@type' => 'sendInlineQueryResultMessage', chat_id => 0 + $chat,
                  query_id => "$query_id", result_id => "$result_id",
                  hide_via_bot => _json_bool($opt{hide_via_bot}) }, $cb);
    return;
}

sub start_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $parameter, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'sendBotStartMessage', bot_user_id => 0 + $bot,
                  chat_id => 0 + ($opt{chat_id} // $bot),
                  parameter => defined $parameter ? "$parameter" : '' }, $cb);
    return;
}

sub attachment_menu_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getAttachmentMenuBot', bot_user_id => 0 + $bot }, $cb);
    return;
}

# openWebApp with an empty url needs the bot to be in the attachment menu
sub toggle_attachment_menu {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $on, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'toggleBotIsAddedToAttachmentMenu',
                  bot_user_id => 0 + $bot,
                  is_added => _json_bool(defined $on ? $on : 1),
                  allow_write_access => _json_bool($opt{allow_write_access}) }, $cb);
    return;
}

# the user's answer to a request_chat / request_users keyboard button; the
# source identifies the message the button was on, and button_id is the id
# you gave that button when building the keyboard
sub _button_source {
    my ($chat_id, $message_id) = @_;
    return { '@type' => 'keyboardButtonSourceMessage',
             chat_id => 0 + $chat_id, message_id => 0 + $message_id };
}

sub share_chat_with_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, $button_id, $shared_chat_id, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, message_id, button_id, shared_chat_id',
          $chat_id, $message_id, $button_id, $shared_chat_id);
    $self->send({
        '@type'          => 'shareChatWithBot',
        source           => _button_source($chat_id, $message_id),
        button_id        => 0 + $button_id,
        shared_chat_id   => 0 + $shared_chat_id,
        only_check       => _json_bool($opt{check_only}),
    }, $cb);
    return;
}

sub share_users_with_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, $button_id, $user_ids, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, message_id, button_id, user_ids',
          $chat_id, $message_id, $button_id, $user_ids);
    croak 'share_users_with_bot needs an arrayref of user ids'
        unless ref $user_ids eq 'ARRAY';
    $self->send({
        '@type'            => 'shareUsersWithBot',
        source             => _button_source($chat_id, $message_id),
        button_id          => 0 + $button_id,
        shared_user_ids    => [ map { 0 + $_ } @$user_ids ],
        only_check         => _json_bool($opt{check_only}),
    }, $cb);
    return;
}

sub allow_bot_messages {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'allowBotToSendMessages',
                  bot_user_id => 0 + $bot }, $cb);
    return;
}

sub can_bot_message {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'canBotSendMessages',
                  bot_user_id => 0 + $bot }, $cb);
    return;
}

# callback query ids are TL int64
sub callback_query_message {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, $query_id, @rest) = @args;
    _need('chat_id, message_id, callback_query_id',
          $chat_id, $message_id, $query_id);
    $self->send({ '@type' => 'getCallbackQueryMessage',
                  chat_id => 0 + $chat_id, message_id => 0 + $message_id,
                  callback_query_id => "$query_id" }, $cb);
    return;
}

sub check_bot_username {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($username, @rest) = @args;
    _need('username', $username);
    $self->send({ '@type' => 'checkBotUsername', username => "$username" }, $cb);
    return;
}

sub toggle_bot_username {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $username, $active, @rest) = @args;
    _need('bot_user_id, username', $bot, $username);
    $self->send({ '@type' => 'toggleBotUsernameIsActive', bot_user_id => 0 + $bot,
                  username => "$username",
                  is_active => _json_bool(defined $active ? $active : 1) }, $cb);
    return;
}

# --- bot provisioning: owning and managing bots from an account, rather than
# through BotFather. createBot names a manager bot that will own the new one.
sub create_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($name, $username, @rest) = @args;
    my %opt = @rest;
    _need('name, username', $name, $username);
    $self->send({
        '@type'                => 'createBot',
        manager_bot_user_id    => 0 + ($opt{manager} // 0),
        name                   => "$name",
        username               => "$username",
        via_link               => _json_bool($opt{via_link}),
    }, $cb);
    return;
}

sub owned_bots {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getOwnedBots' }, $cb);
    return;
}

# revoke invalidates the old token, so anything still using it stops working
sub bot_token {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getManagedBotToken', bot_user_id => 0 + $bot,
                  revoke => _json_bool($opt{revoke}) }, $cb);
    return;
}

sub bot_access_settings {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getManagedBotAccessSettings',
                  bot_user_id => 0 + $bot }, $cb);
    return;
}

sub set_bot_access_settings {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $settings, @rest) = @args;
    _need('bot_user_id, settings', $bot, $settings);
    croak 'set_bot_access_settings needs a settings hashref'
        unless ref $settings eq 'HASH';
    $self->send({ '@type' => 'setManagedBotAccessSettings',
                  bot_user_id => 0 + $bot, settings => $settings }, $cb);
    return;
}

sub set_updates_status {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($pending, @rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'setBotUpdatesStatus',
                  pending_update_count => 0 + ($pending // 0),
                  error_message => $opt{error} // '' }, $cb);
    return;
}

sub recent_inline_bots {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getRecentInlineBots' }, $cb);
    return;
}

sub similar_bots {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getBotSimilarBots', bot_user_id => 0 + $bot }, $cb);
    return;
}

sub similar_bot_count {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getBotSimilarBotCount', bot_user_id => 0 + $bot,
                  return_local => _json_bool($opt{local}) }, $cb);
    return;
}

sub open_similar_bot {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $opened, @rest) = @args;
    _need('bot_user_id, opened_bot_user_id', $bot, $opened);
    $self->send({ '@type' => 'openBotSimilarBot', bot_user_id => 0 + $bot,
                  opened_bot_user_id => 0 + $opened }, $cb);
    return;
}

# --- media previews: the sample media shown on a bot's profile, per language
sub bot_media_previews {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    my %req = ('@type' => 'getBotMediaPreviews', bot_user_id => 0 + $bot);
    if (defined $opt{language_code}) {
        $req{'@type'} = 'getBotMediaPreviewInfo';
        $req{language_code} = "$opt{language_code}";
    }
    $self->send(\%req, $cb);
    return;
}

sub add_bot_media_preview {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $content, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id, content', $bot, $content);
    $self->send({ '@type' => 'addBotMediaPreview', bot_user_id => 0 + $bot,
                  language_code => $opt{language_code} // '',
                  content => $content }, $cb);
    return;
}

sub edit_bot_media_preview {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $file_id, $content, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id, file_id, content', $bot, $file_id, $content);
    $self->send({ '@type' => 'editBotMediaPreview', bot_user_id => 0 + $bot,
                  language_code => $opt{language_code} // '',
                  file_id => 0 + $file_id, content => $content }, $cb);
    return;
}

sub delete_bot_media_previews {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $file_ids, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id, file_ids', $bot, $file_ids);
    croak 'delete_bot_media_previews needs an arrayref of file ids'
        unless ref $file_ids eq 'ARRAY';
    $self->send({ '@type' => 'deleteBotMediaPreviews', bot_user_id => 0 + $bot,
                  language_code => $opt{language_code} // '',
                  file_ids => [ map { 0 + $_ } @$file_ids ] }, $cb);
    return;
}

sub reorder_bot_media_previews {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $file_ids, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id, file_ids', $bot, $file_ids);
    croak 'reorder_bot_media_previews needs an arrayref of file ids'
        unless ref $file_ids eq 'ARRAY';
    $self->send({ '@type' => 'reorderBotMediaPreviews', bot_user_id => 0 + $bot,
                  language_code => $opt{language_code} // '',
                  file_ids => [ map { 0 + $_ } @$file_ids ] }, $cb);
    return;
}

# --- games: a game bot cannot report a result without these
sub set_game_score {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, $user_id, $score, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, message_id, user_id, score',
          $chat_id, $message_id, $user_id, $score);
    $self->send({
        '@type'        => 'setGameScore',
        chat_id        => 0 + $chat_id,
        message_id     => 0 + $message_id,
        edit_message   => _json_bool(exists $opt{edit} ? $opt{edit} : 1),
        user_id        => 0 + $user_id,
        score          => 0 + $score,
        # without force a lower score is refused, which is usually what you want
        force          => _json_bool($opt{force}),
    }, $cb);
    return;
}

sub game_high_scores {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $message_id, $user_id, @rest) = @args;
    _need('chat_id, message_id, user_id', $chat_id, $message_id, $user_id);
    $self->send({ '@type' => 'getGameHighScores', chat_id => 0 + $chat_id,
                  message_id => 0 + $message_id, user_id => 0 + $user_id }, $cb);
    return;
}

sub set_inline_game_score {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($inline_id, $user_id, $score, @rest) = @args;
    my %opt = @rest;
    _need('inline_message_id, user_id, score', $inline_id, $user_id, $score);
    $self->send({
        '@type'             => 'setInlineGameScore',
        inline_message_id   => "$inline_id",
        edit_message        => _json_bool(exists $opt{edit} ? $opt{edit} : 1),
        user_id             => 0 + $user_id,
        score               => 0 + $score,
        force               => _json_bool($opt{force}),
    }, $cb);
    return;
}

sub inline_game_high_scores {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($inline_id, $user_id, @rest) = @args;
    _need('inline_message_id, user_id', $inline_id, $user_id);
    $self->send({ '@type' => 'getInlineGameHighScores',
                  inline_message_id => "$inline_id", user_id => 0 + $user_id }, $cb);
    return;
}


# the button beside the message box; a web_app url makes it open a Mini App
sub set_menu_button {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'      => 'setMenuButton',
        user_id      => 0 + ($user_id // 0),
        menu_button  => { '@type' => 'botMenuButton',
                          text => $opt{text} // '',
                          url  => $opt{url}  // '' },
    }, $cb);
    return;
}

sub menu_button {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    $self->send({ '@type' => 'getMenuButton', user_id => 0 + ($user_id // 0) }, $cb);
    return;
}

1;
