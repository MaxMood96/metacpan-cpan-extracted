package EV::Telegram::TDLib::Folders;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES;

my @FOLDER_FLAGS = qw(
    exclude_muted exclude_read exclude_archived
    include_contacts include_non_contacts include_bots
    include_groups include_channels
);
my @FOLDER_LISTS = qw(pinned_chat_ids included_chat_ids excluded_chat_ids);

# the name is a chatFolderName wrapping a formattedText, not a plain string;
# passing a string yields only "Chat folder name must be non-empty"
sub _folder {
    my ($spec) = @_;
    croak 'a folder needs a hashref' unless ref $spec eq 'HASH';
    croak 'a folder needs a name' unless defined $spec->{name} && length $spec->{name};
    return {
        '@type' => 'chatFolder',
        name    => {
            '@type'                => 'chatFolderName',
            text                   => { '@type' => 'formattedText',
                                        text => "$spec->{name}", entities => [] },
            animate_custom_emoji   => _json_bool($spec->{animate_emoji}),
        },
        (defined $spec->{icon}
            ? (icon => { '@type' => 'chatFolderIcon', name => "$spec->{icon}" }) : ()),
        color_id      => 0 + (defined $spec->{color_id} ? $spec->{color_id} : -1),
        is_shareable  => _json_bool($spec->{shareable}),
        (map { $_ => [ map { 0 + $_ } @{ $spec->{$_} || [] } ] } @FOLDER_LISTS),
        (map { $_ => _json_bool($spec->{$_}) } @FOLDER_FLAGS),
    };
}

sub folder {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    _need('chat_folder_id', $id);
    $self->send({ '@type' => 'getChatFolder', chat_folder_id => 0 + $id }, $cb);
    return;
}

sub create_folder {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($spec, @rest) = @args;
    _need('folder', $spec);
    $self->send({ '@type' => 'createChatFolder', folder => _folder($spec) }, $cb);
    return;
}

sub edit_folder {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $spec, @rest) = @args;
    _need('chat_folder_id, folder', $id, $spec);
    $self->send({ '@type' => 'editChatFolder', chat_folder_id => 0 + $id,
                  folder => _folder($spec) }, $cb);
    return;
}

sub delete_folder {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('chat_folder_id', $id);
    $self->send({ '@type' => 'deleteChatFolder', chat_folder_id => 0 + $id,
                  leave_chat_ids =>
                      [ map { 0 + $_ } @{ $opt{leave_chats} || [] } ] }, $cb);
    return;
}

sub reorder_folders {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($ids, @rest) = @args;
    my %opt = @rest;
    _need('chat_folder_ids', $ids);
    croak 'reorder_folders needs an arrayref of folder ids' unless ref $ids eq 'ARRAY';
    $self->send({
        '@type'                   => 'reorderChatFolders',
        chat_folder_ids           => [ map { 0 + $_ } @$ids ],
        main_chat_list_position   => 0 + ($opt{main_position} // 0),
    }, $cb);
    return;
}

sub recommended_folders {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getRecommendedChatFolders' }, $cb);
    return;
}

sub folder_chat_count {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($spec, @rest) = @args;
    _need('folder', $spec);
    $self->send({ '@type' => 'getChatFolderChatCount', folder => _folder($spec) }, $cb);
    return;
}

sub folder_tags {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($on, @rest) = @args;
    $self->send({ '@type' => 'toggleChatFolderTags',
                  are_tags_enabled => _json_bool(defined $on ? $on : 1) }, $cb);
    return;
}

sub folder_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('chat_folder_id', $id);
    $self->send({
        '@type'          => 'createChatFolderInviteLink',
        chat_folder_id   => 0 + $id,
        name             => $opt{name} // '',
        chat_ids         => [ map { 0 + $_ } @{ $opt{chats} || [] } ],
    }, $cb);
    return;
}

sub folder_invite_links {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    _need('chat_folder_id', $id);
    $self->send({ '@type' => 'getChatFolderInviteLinks',
                  chat_folder_id => 0 + $id }, $cb);
    return;
}

sub edit_folder_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $link, @rest) = @args;
    my %opt = @rest;
    _need('chat_folder_id, invite_link', $id, $link);
    $self->send({
        '@type'          => 'editChatFolderInviteLink',
        chat_folder_id   => 0 + $id,
        invite_link      => "$link",
        name             => $opt{name} // '',
        chat_ids         => [ map { 0 + $_ } @{ $opt{chats} || [] } ],
    }, $cb);
    return;
}

sub delete_folder_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, $link, @rest) = @args;
    _need('chat_folder_id, invite_link', $id, $link);
    $self->send({ '@type' => 'deleteChatFolderInviteLink',
                  chat_folder_id => 0 + $id, invite_link => "$link" }, $cb);
    return;
}

sub check_folder_invite_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($link, @rest) = @args;
    _need('invite_link', $link);
    $self->send({ '@type' => 'checkChatFolderInviteLink',
                  invite_link => "$link" }, $cb);
    return;
}

sub add_folder_by_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($link, @rest) = @args;
    my %opt = @rest;
    _need('invite_link', $link);
    $self->send({
        '@type'      => 'addChatFolderByInviteLink',
        invite_link  => "$link",
        chat_ids     => [ map { 0 + $_ } @{ $opt{chats} || [] } ],
    }, $cb);
    return;
}

1;
