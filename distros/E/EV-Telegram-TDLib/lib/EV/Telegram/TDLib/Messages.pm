package EV::Telegram::TDLib::Messages;

use strict;
use warnings;
use Carp qw(croak);
use EV;
use Encode ();

our $VERSION = '0.02';

sub CLONE_SKIP { 1 }

my %PARSE_MODE = (
    markdown => { '@type' => 'textParseModeMarkdown', version => 2 },
    html     => { '@type' => 'textParseModeHTML' },
);

our %UPDATES = (
    updateNewMessage            => \&_update_new_message,
    updateMessageSendSucceeded  => \&_update_send_succeeded,
    updateMessageSendFailed     => \&_update_send_failed,
);

sub _sending { $_[0]{cache}{sending} ||= {} }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

sub _update_new_message {
    my ($self, $obj) = @_;
    my $msg = $obj->{message} or return;
    if (my $cb = $self->{on_message}) { $cb->($msg) }
}

sub _update_send_succeeded {
    my ($self, $obj) = @_;
    return unless defined $obj->{old_message_id};
    my $cb = delete $self->_sending->{ $obj->{old_message_id} } or return;
    $cb->($obj->{message}, undef);
}

sub _update_send_failed {
    my ($self, $obj) = @_;
    return unless defined $obj->{old_message_id};
    my $cb = delete $self->_sending->{ $obj->{old_message_id} } or return;
    $cb->(undef, $obj->{error} // { '@type' => 'error', code => -1,
                                    message => 'message send failed' });
}

sub on_message {
    my ($self, $cb) = @_;
    $self->{on_message} = $cb if $cb;
    return $self->{on_message};
}

sub _format_text {
    my ($self, $text, $parse_mode) = @_;
    return { '@type' => 'formattedText', text => $text, entities => [] }
        unless $parse_mode;
    my $mode = $PARSE_MODE{$parse_mode}
        or croak "unknown parse_mode '$parse_mode'";
    return $self->execute({
        '@type' => 'parseTextEntities', text => $text, parse_mode => $mode,
    });
}

sub _input_text {
    my ($self, $text, $opt, $cb) = @_;
    my $formatted = $self->_format_text($text, $opt->{parse_mode});
    if (($formatted->{'@type'} // '') eq 'error') {
        $cb->(undef, $formatted);
        return;
    }
    my %content = ('@type' => 'inputMessageText', text => $formatted);
    $content{link_preview_options} = { '@type' => 'linkPreviewOptions',
                                       is_disabled => _json_bool(1) }
        if $opt->{disable_preview};
    return \%content;
}

sub send_message {
    my ($self, $chat_id, $text, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $content = $self->_input_text($text, \%opt, $cb) or return;
    $self->_send_content($chat_id, $content, \%opt, $cb);
    return;
}

# every send shares this tail so reply_to/silent/reply_markup and the
# temporary-id dance are defined in exactly one place
sub _send_content {
    my ($self, $chat_id, $content, $opt, $cb) = @_;
    my $wait = $opt->{wait} // 'sent';
    # every sender shares this check: validating in only some of them let
    # send_poll and friends accept a typo and silently mean 'sent'
    croak "unknown wait mode '$wait'"
        unless $wait eq 'sent' || $wait eq 'accepted';
    my %req = (
        '@type' => 'sendMessage',
        chat_id => 0 + $chat_id,
        input_message_content => $content,
    );
    $req{reply_to} = { '@type' => 'inputMessageReplyToMessage',
                       message_id => 0 + $opt->{reply_to} } if $opt->{reply_to};
    $req{options} = { '@type' => 'messageSendOptions',
                      disable_notification => _json_bool(1) } if $opt->{silent};
    $req{reply_markup} = $opt->{reply_markup} if $opt->{reply_markup};
    $self->send(\%req, sub {
        my ($msg, $err) = @_;
        if ($err) { $cb->(undef, $err); return }
        if ($wait eq 'accepted') { $cb->($msg, undef); return }
        # the reply carries a temporary id; the real outcome arrives later as
        # updateMessageSendSucceeded/Failed keyed by that id
        $self->_sending->{ $msg->{id} } = $cb;
    });
    return;
}

# each media content nests its InputFile inside a per-kind wrapper object;
# passing the InputFile directly yields only "InputFile is not specified"
# kind => [ content type, field, wrapper type, takes a caption ]
# stickers and video notes have no caption field in the schema at all
my %MEDIA = (
    document   => ['inputMessageDocument',  'document',   'inputDocument',  1],
    photo      => ['inputMessagePhoto',     'photo',      'inputPhoto',     1],
    video      => ['inputMessageVideo',     'video',      'inputVideo',     1],
    audio      => ['inputMessageAudio',     'audio',      'inputAudio',     1],
    animation  => ['inputMessageAnimation', 'animation',  'inputAnimation', 1],
    voice_note => ['inputMessageVoiceNote', 'voice_note', 'inputVoiceNote', 1],
    video_note => ['inputMessageVideoNote', 'video_note', 'inputVideoNote', 0],
    sticker    => ['inputMessageSticker',   'sticker',    'inputSticker',   0],
);

# optional wrapper fields worth exposing, per kind
my %MEDIA_EXTRA = (
    photo      => [qw(width height)],
    video      => [qw(duration width height)],
    audio      => [qw(duration title performer)],
    animation  => [qw(duration width height)],
    voice_note => [qw(duration)],
    video_note => [qw(duration length)],
    sticker    => [qw(width height)],
);
my %STRING_EXTRA = map { $_ => 1 } qw(title performer);

sub send_file {
    my ($self, $chat_id, $path, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, path', $chat_id, $path);
    my $kind = $opt{kind} // 'document';
    my $spec = $MEDIA{$kind} or croak "unknown file kind '$kind'";
    my ($content_type, $field, $wrapper, $has_caption) = @$spec;
    my $input = ref $path eq 'HASH' ? $path : $self->upload($path);
    my $content = {
        '@type' => $content_type,
        $field  => { '@type' => $wrapper, $field => $input },
    };
    if ($has_caption) {
        my $caption = $self->_format_text($opt{caption} // '', $opt{parse_mode});
        if (($caption->{'@type'} // '') eq 'error') { $cb->(undef, $caption); return }
        $content->{caption} = $caption;
    }
    $content->{emoji} = "$opt{emoji}" if $kind eq 'sticker' && defined $opt{emoji};
    # Telegram classifies media by the metadata it is given: an animation
    # with no duration/width/height comes back as a plain document
    for my $extra (@{ $MEDIA_EXTRA{$kind} || [] }) {
        next unless defined $opt{$extra};
        $content->{$field}{$extra} = $STRING_EXTRA{$extra}
            ? "$opt{$extra}" : 0 + $opt{$extra};
    }
    $self->_send_content($chat_id, $content, \%opt, $cb);
    return;
}

sub search_messages {
    my ($self, $chat_id, $query, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    $self->send({
        '@type'           => 'searchChatMessages',
        chat_id           => 0 + $chat_id,
        query             => "$query",
        from_message_id   => 0 + ($opt{from_message_id} // 0),
        offset            => 0 + ($opt{offset} // 0),
        limit             => 0 + ($opt{limit} // 50),
        filter            => { '@type' => 'searchMessagesFilterEmpty' },
    }, sub {
        my ($res, $err) = @_;
        if ($err) { $cb->(undef, $err); return }
        $cb->($res->{messages} // [], undef, {
            total_count          => $res->{total_count},
            next_from_message_id => $res->{next_from_message_id},
        });
    });
    return;
}

sub history {
    my ($self, $chat_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $want      = $opt{limit} // 50;
    my $max_pages = $opt{max_pages} // 10;
    my $from      = $opt{from_message_id} // 0;
    my @msgs;
    my $pages = 0;
    my $state = { complete => 0, last_message_id => undef };
    my ($fetch, $finish, $defer);
    $finish = sub {
        undef $fetch;  # break the fetch/finish closure cycle
        # a degenerate limit or max_pages finishes without ever sending a
        # request; firing inline would break the deferred-callback rule
        if (!$pages) {
            my @args = @_;
            $defer = EV::timer 0, 0, sub { undef $defer; $cb->(@args) };
            return;
        }
        $cb->(@_);
    };
    $fetch = sub {
        my $left = $want - @msgs;
        if ($left <= 0 || $pages >= $max_pages) {
            $state->{complete} = 1 if $left <= 0;
            $finish->(\@msgs, undef, $state);
            return;
        }
        $pages++;
        $self->send({
            '@type' => 'getChatHistory',
            chat_id => 0 + $chat_id,
            from_message_id => 0 + $from,
            offset => 0,
            limit => $left > 100 ? 100 : 0 + $left,
            only_local => _json_bool(0),
        }, sub {
            my ($res, $err) = @_;
            if ($err) {
                $finish->(@msgs ? \@msgs : undef, $err, $state);
                return;
            }
            my $batch = $res->{messages} // [];
            if (!@$batch) { $state->{complete} = 1; $finish->(\@msgs, undef, $state); return }
            push @msgs, @$batch;
            my $last = $batch->[-1]{id};
            $state->{last_message_id} = $last;
            # a batch that does not advance would loop forever
            if ($last == $from) { $state->{complete} = 1; $finish->(\@msgs, undef, $state); return }
            $from = $last;
            $fetch->();
        });
    };
    $fetch->();
    return;
}

sub edit_message {
    my ($self, $chat_id, $message_id, $text, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $content = $self->_input_text($text, \%opt, $cb) or return;
    my %req = (
        '@type' => 'editMessageText',
        chat_id => 0 + $chat_id,
        message_id => 0 + $message_id,
        input_message_content => $content,
    );
    # an edit without reply_markup drops the buttons the message had
    $req{reply_markup} = $opt{reply_markup} if $opt{reply_markup};
    $self->send(\%req, $cb);
    return;
}

sub edit_message_markup {
    my ($self, $chat_id, $message_id, $markup, $cb) = @_;
    $cb ||= sub {};
    $self->send({
        '@type'      => 'editMessageReplyMarkup',
        chat_id      => 0 + $chat_id,
        message_id   => 0 + $message_id,
        reply_markup => $markup,
    }, $cb);
    return;
}

sub react {
    my ($self, $chat_id, $message_id, $emoji, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, message_id, emoji', $chat_id, $message_id, $emoji);
    my %req = (
        chat_id       => 0 + $chat_id,
        message_id    => 0 + $message_id,
        reaction_type => { '@type' => 'reactionTypeEmoji', emoji => "$emoji" },
    );
    if ($opt{remove}) {
        $req{'@type'} = 'removeMessageReaction';
    } else {
        $req{'@type'} = 'addMessageReaction';
        $req{is_big} = _json_bool($opt{is_big});
        $req{update_recent_reactions} =
            _json_bool(exists $opt{update_recent} ? $opt{update_recent} : 1);
    }
    $self->send(\%req, $cb);
    return;
}

sub delete_messages {
    my ($self, $chat_id, $message_ids, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    $self->send({
        '@type' => 'deleteMessages',
        chat_id => 0 + $chat_id,
        message_ids => [ map { 0 + $_ } @$message_ids ],
        revoke => _json_bool(exists $opt{revoke} ? $opt{revoke} : 1),
    }, $cb);
    return;
}

sub forward_messages {
    my ($self, $chat_id, $from_chat_id, $message_ids, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my %req = (
        '@type' => 'forwardMessages',
        chat_id => 0 + $chat_id,
        from_chat_id => 0 + $from_chat_id,
        message_ids => [ map { 0 + $_ } @$message_ids ],
        send_copy => _json_bool($opt{send_copy}),
        remove_caption => _json_bool($opt{remove_caption}),
    );
    $req{options} = { '@type' => 'messageSendOptions',
                      disable_notification => _json_bool(1) } if $opt{silent};
    $self->send(\%req, $cb);
    return;
}

sub send_poll {
    my ($self, $chat_id, $question, $options, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, question', $chat_id, $question);
    croak 'send_poll needs an arrayref of options' unless ref $options eq 'ARRAY';
    croak 'a poll needs at least two options' unless @$options >= 2;
    # a parse failure comes back as an error object; embedding it would send
    # TDLib nonsense instead of telling the caller what was wrong
    my $bad;
    my $fmt = sub {
        my $t = $self->_format_text($_[0], $opt{parse_mode});
        $bad ||= $t if ($t->{'@type'} // '') eq 'error';
        return $t;
    };
    my $type = $opt{quiz}
        ? { '@type' => 'inputPollTypeQuiz',
            correct_option_ids => [ 0 + ($opt{correct} // 0) ],
            explanation => $fmt->($opt{explanation} // '') }
        : { '@type' => 'inputPollTypeRegular',
            allow_adding_options => _json_bool($opt{allow_adding_options}) };
    my $content = {
        '@type'    => 'inputMessagePoll',
        question   => $fmt->($question),
        options    => [ map { +{ '@type' => 'inputPollOption',
                                 text => $fmt->($_) } } @$options ],
        type       => $type,
        # TDLib defaults is_anonymous to false, which surprises: Telegram's
        # own clients create anonymous polls
        is_anonymous => _json_bool(exists $opt{anonymous} ? $opt{anonymous} : 1),
        allows_multiple_answers => _json_bool($opt{multiple}),
        (defined $opt{open_period} ? (open_period => 0 + $opt{open_period}) : ()),
    };
    if ($bad) { $cb->(undef, $bad); return }
    $self->_send_content($chat_id, $content, \%opt, $cb);
    return;
}

sub send_location {
    my ($self, $chat_id, $lat, $lon, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, latitude, longitude', $chat_id, $lat, $lon);
    $self->_send_content($chat_id, {
        '@type'  => 'inputMessageLocation',
        location => { '@type' => 'location',
                      latitude => 0 + $lat, longitude => 0 + $lon,
                      horizontal_accuracy => 0 + ($opt{accuracy} // 0) },
    }, \%opt, $cb);
    return;
}

sub send_contact {
    my ($self, $chat_id, $phone, $first, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    _need('chat_id, phone, first_name', $chat_id, $phone, $first);
    $self->_send_content($chat_id, {
        '@type'  => 'inputMessageContact',
        contact  => { '@type' => 'contact',
                      phone_number => "$phone",
                      first_name   => "$first",
                      last_name    => $opt{last_name} // '',
                      vcard        => $opt{vcard} // '',
                      user_id      => 0 + ($opt{user_id} // 0) },
    }, \%opt, $cb);
    return;
}

# TDLib counts entity offsets and lengths in UTF-16 code units, which is not
# what perl's substr counts: any character outside the BMP is two units but
# one character, so substr silently returns the wrong run. The offsets are
# left exactly as TDLib sent them -- they travel back unchanged when a
# message is forwarded, edited or copied, and rewriting them would corrupt
# that -- so slicing is offered here instead.
sub entity_text {
    my ($self, $ft, $entity) = @_;
    ($ft, $entity) = ($self, $ft) if @_ == 2;   # usable as a plain function
    croak 'entity_text needs a formattedText and an entity'
        unless ref $ft eq 'HASH' && ref $entity eq 'HASH';
    my $text = $ft->{text};
    return undef unless defined $text;
    my ($off, $len) = @{$entity}{qw(offset length)};
    return undef unless defined $off && defined $len;
    my $units = Encode::encode('UTF-16LE', $text);
    return undef if $off * 2 > length $units;
    return Encode::decode('UTF-16LE', substr $units, $off * 2, $len * 2);
}

# Every entity of a formattedText, already sliced. Each element carries the
# entity's own fields plus the text it covers, so a caller never touches an
# offset at all.
sub entity_texts {
    my ($self, $ft) = @_;
    $ft = $self if @_ == 1;
    croak 'entity_texts needs a formattedText' unless ref $ft eq 'HASH';
    my @out;
    for my $e (@{ $ft->{entities} || [] }) {
        push @out, {
            %$e,
            # guarded: reaching through a missing type would autovivify it
            # in the caller's own entity
            type => (ref $e->{type} eq 'HASH' ? $e->{type}{'@type'} : undef),
            text => entity_text($ft, $e),
        };
    }
    return \@out;
}

1;
