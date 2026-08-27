package EV::Telegram::TDLib::Users;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.02';

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
    my ($self, $path, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    $self->send({
        '@type'   => 'setProfilePhoto',
        photo     => $self->_input_chat_photo($path, \%opt),
        is_public => _json_bool(exists $opt{public} ? $opt{public} : 1),
    }, $cb);
    return;
}

sub set_name {
    my ($self, $first, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
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

1;
