package EV::Telegram::TDLib::Users;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES = (
    updateUser => \&_update_user,
);

sub _users { $_[0]{cache}{users} ||= {} }

sub _update_user {
    my ($self, $obj) = @_;
    my $user = $obj->{user} or return;
    $self->_users->{ $user->{id} } = $user;
    if (my $cb = $self->{on_user}) { $cb->($user) }
}

sub me {
    my ($self, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'getMe' }, sub {
        my ($user, $err) = @_;
        $self->_users->{ $user->{id} } = $user if $user;
        $cb->($user, $err);
    });
}

sub user {
    my ($self, $id) = @_;
    return $self->_users->{$id};
}

sub on_user {
    my ($self, $cb) = @_;
    $self->{on_user} = $cb if $cb;
    return $self->{on_user};
}

# searchPublicChat resolves any public @name; only a private chat carries a
# user behind it, so a channel or group is reported as such rather than undef
sub user_by_username {
    my ($self, $name, $cb) = @_;
    $cb ||= sub {};
    $name =~ s/^\@//;
    $self->send({ '@type' => 'searchPublicChat', username => $name }, sub {
        my ($chat, $err) = @_;
        if ($err) { $cb->(undef, $err); return }
        my $uid = $chat->{type}{user_id};
        if (!$uid) {
            $cb->(undef, { '@type' => 'error', code => -1,
                           message => "\@$name is not a user" });
            return;
        }
        $self->send({ '@type' => 'getUser', user_id => 0 + $uid }, sub {
            my ($user, $err) = @_;
            $self->_users->{ $user->{id} } = $user if $user;
            $cb->($user, $err);
        });
    });
    return;
}

# a profile photo is an InputChatPhoto, which wraps an InputFile the same way
# message media do; an animated one also needs the frame to show when still
sub _input_chat_photo {
    my ($self, $path, $opt) = @_;
    my $file = ref $path eq 'HASH' ? $path : $self->upload($path);
    return { '@type' => 'inputChatPhotoStatic', photo => $file }
        unless $opt->{animation};
    return {
        '@type'    => 'inputChatPhotoAnimation',
        animation  => $file,
        main_frame_timestamp => 0 + ($opt->{main_frame_timestamp} // 0),
    };
}

sub set_profile_photo {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($path, @rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'   => 'setProfilePhoto',
        photo     => $self->_input_chat_photo($path, \%opt),
        is_public => _json_bool(exists $opt{public} ? $opt{public} : 1),
    }, $cb);
    return;
}

sub set_name {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($first, @rest) = @args;
    my ($last) = @rest;
    croak 'set_name needs a first name' unless defined $first && length $first;
    $self->send({ '@type' => 'setName', first_name => "$first",
                  last_name => defined $last ? "$last" : '' }, $cb);
    return;
}

sub set_bio {
    my ($self, $bio, $cb) = @_;
    $cb ||= sub {};
    $self->send({ '@type' => 'setBio', bio => defined $bio ? "$bio" : '' }, $cb);
    return;
}

sub set_username {
    my ($self, $name, $cb) = @_;
    $cb ||= sub {};
    $name = '' unless defined $name;
    $name =~ s/^\@//;
    $self->send({ '@type' => 'setUsername', username => "$name" }, $cb);
    return;
}

# a contact carries a phone number even when the user id is known: Telegram
# matches on the number, and an empty one simply means "no number to import"
sub _contact {
    my ($spec) = @_;
    croak 'each contact must be a hashref' unless ref $spec eq 'HASH';
    my $contact = {
        '@type'       => 'importedContact',
        phone_number  => $spec->{phone}      // '',
        first_name    => $spec->{first_name} // '',
        last_name     => $spec->{last_name}  // '',
    };
    $contact->{note} = { '@type' => 'formattedText',
                         text => "$spec->{note}", entities => [] }
        if defined $spec->{note};
    return $contact;
}

sub contacts {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getContacts' }, $cb);
    return;
}

sub add_contact {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    my %opt = @rest;
    _need('user_id', $user_id);
    $self->send({
        '@type'              => 'addContact',
        user_id              => 0 + $user_id,
        contact              => _contact(\%opt),
        share_phone_number   => _json_bool($opt{share_phone}),
    }, $cb);
    return;
}

sub remove_contacts {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_ids, @rest) = @args;
    _need('user_ids', $user_ids);
    croak 'remove_contacts needs an arrayref of user ids' unless ref $user_ids eq 'ARRAY';
    $self->send({ '@type' => 'removeContacts',
                  user_ids => [ map { 0 + $_ } @$user_ids ] }, $cb);
    return;
}

sub search_contacts {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query, @rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'searchContacts',
                  query => defined $query ? "$query" : '',
                  limit => 0 + ($opt{limit} // 50) }, $cb);
    return;
}

sub import_contacts {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($list, @rest) = @args;
    _need('contacts', $list);
    croak 'import_contacts needs an arrayref of contacts' unless ref $list eq 'ARRAY';
    $self->send({ '@type' => 'importContacts',
                  contacts => [ map { _contact($_) } @$list ] }, $cb);
    return;
}

# an omitted birthdate clears it; year is optional and 0 means unstated
sub set_birthdate {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    my %req = ('@type' => 'setBirthdate');
    if (defined $opt{day} && defined $opt{month}) {
        $req{birthdate} = { '@type' => 'birthdate',
                            day => 0 + $opt{day}, month => 0 + $opt{month},
                            year => 0 + ($opt{year} // 0) };
    }
    $self->send(\%req, $cb);
    return;
}

sub set_accent_color {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($color_id, @rest) = @args;
    my %opt = @rest;
    _need('accent_color_id', $color_id);
    $self->send({ '@type' => 'setAccentColor', accent_color_id => 0 + $color_id,
                  background_custom_emoji_id =>
                      "" . ($opt{background_custom_emoji_id} // 0) }, $cb);
    return;
}

sub profile_photos {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, @rest) = @args;
    my %opt = @rest;
    _need('user_id', $user_id);
    $self->send({ '@type' => 'getUserProfilePhotos', user_id => 0 + $user_id,
                  offset => 0 + ($opt{offset} // 0),
                  limit => 0 + ($opt{limit} // 100) }, $cb);
    return;
}

# profile photo ids are TL int64
sub delete_profile_photo {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($photo_id, @rest) = @args;
    _need('profile_photo_id', $photo_id);
    $self->send({ '@type' => 'deleteProfilePhoto',
                  profile_photo_id => "$photo_id" }, $cb);
    return;
}


sub search_by_phone {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($phone, @rest) = @args;
    my %opt = @rest;
    _need('phone_number', $phone);
    $self->send({ '@type' => 'searchUserByPhoneNumber', phone_number => "$phone",
                  only_local => _json_bool($opt{local}) }, $cb);
    return;
}

sub my_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getUserLink' }, $cb);
    return;
}

sub toggle_username {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($username, $active, @rest) = @args;
    _need('username', $username);
    $self->send({ '@type' => 'toggleUsernameIsActive', username => "$username",
                  is_active => _json_bool(defined $active ? $active : 1) }, $cb);
    return;
}

my %PRIVACY = (
    status          => 'userPrivacySettingShowStatus',
    profile_photo   => 'userPrivacySettingShowProfilePhoto',
    phone           => 'userPrivacySettingShowPhoneNumber',
    bio             => 'userPrivacySettingShowBio',
    birthdate       => 'userPrivacySettingShowBirthdate',
    forwards        => 'userPrivacySettingShowLinkInForwardedMessages',
    invites         => 'userPrivacySettingAllowChatInvites',
    calls           => 'userPrivacySettingAllowCalls',
    find_by_phone   => 'userPrivacySettingAllowFindingByPhoneNumber',
);

sub privacy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($setting, @rest) = @args;
    my $t = $PRIVACY{ $setting // '' }
        or croak "unknown privacy setting '" . ($setting // '') . "'";
    $self->send({ '@type' => 'getUserPrivacySettingRules',
                  setting => { '@type' => $t } }, $cb);
    return;
}

# rules are an ordered list and the first match wins, so their order matters
sub set_privacy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($setting, $rules, @rest) = @args;
    _need('setting, rules', $setting, $rules);
    croak 'set_privacy needs an arrayref of rules' unless ref $rules eq 'ARRAY';
    my $t = $PRIVACY{$setting} or croak "unknown privacy setting '$setting'";
    $self->send({ '@type' => 'setUserPrivacySettingRules',
                  setting => { '@type' => $t },
                  rules   => { '@type' => 'userPrivacySettingRules',
                               rules => $rules } }, $cb);
    return;
}

1;
