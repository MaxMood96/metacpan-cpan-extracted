package EV::Telegram::TDLib::Bots;

use strict;
use warnings;
use Carp qw(croak);
use MIME::Base64 ();

our $VERSION = '0.02';

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
    my ($self, $id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
                : croak 'each button needs either data or url';
            push @buttons, { '@type' => 'inlineKeyboardButton',
                             text => "$b->{text}", type => $type };
        }
        push @out, \@buttons;
    }
    return { '@type' => 'replyMarkupInlineKeyboard', rows => \@out };
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
            my $type = !defined $b->{request}      ? 'keyboardButtonTypeText'
                     : $b->{request} eq 'phone'    ? 'keyboardButtonTypeRequestPhoneNumber'
                     : $b->{request} eq 'location' ? 'keyboardButtonTypeRequestLocation'
                     : croak "unknown button request '$b->{request}'";
            +{ '@type' => 'keyboardButton', text => "$b->{text}",
               type => { '@type' => $type } };
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
    my ($self, $commands, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
    my ($self, $name, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
    my ($self, $text, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
    my ($self, $text, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
    my ($self, $path, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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
    my ($self, $id, $results, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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

1;
