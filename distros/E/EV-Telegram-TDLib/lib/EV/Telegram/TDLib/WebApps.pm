package EV::Telegram::TDLib::WebApps;

use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES;

my %MODE = (
    full_size   => 'webAppOpenModeFullSize',
    compact     => 'webAppOpenModeCompact',
    full_screen => 'webAppOpenModeFullScreen',
);

# Telegram takes this as the platform identifier and hands it to the app as
# tgWebAppPlatform. The class is spelled out because \w is Unicode-aware and
# would pass names the server rejects as PLATFORM_INVALID, which names
# nothing near the cause.
sub _check_application_name {
    my ($name) = @_;
    croak "application_name must be 0-64 letters, digits or underscores"
        . (defined $name ? " (got '$name')" : '')
        unless defined $name && $name =~ /\A[A-Za-z0-9_]{0,64}\z/;
    return $name;
}

sub _open_params {
    my ($self, $opt) = @_;
    my $mode = $opt->{mode} // 'full_size';
    croak "unknown web app mode '$mode'" unless $MODE{$mode};
    return {
        '@type'          => 'webAppOpenParameters',
        application_name => defined $opt->{application_name}
            ? _check_application_name($opt->{application_name})
            : $self->{application_name},
        mode             => { '@type' => $MODE{$mode} },
        (defined $opt->{theme} ? (theme => $opt->{theme}) : ()),
    };
}

sub web_app {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $name, @rest) = @args;
    _need('bot_user_id, short_name', $bot, $name);
    $self->send({ '@type' => 'searchWebApp',
                  bot_user_id => 0 + $bot, web_app_short_name => "$name" }, $cb);
    return;
}

sub web_app_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $bot, $name, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, bot_user_id, short_name', $chat, $bot, $name);
    $self->send({
        '@type'             => 'getWebAppLinkUrl',
        chat_id             => 0 + $chat,
        bot_user_id         => 0 + $bot,
        web_app_short_name  => "$name",
        start_parameter     => $opt{start_parameter} // '',
        allow_write_access  => _json_bool($opt{allow_write_access}),
        parameters          => _open_params($self, \%opt),
    }, $cb);
    return;
}

sub web_app_url {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    my %opt = @rest;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getWebAppUrl', bot_user_id => 0 + $bot,
                  url => $opt{url} // '',
                  parameters => _open_params($self, \%opt) }, $cb);
    return;
}

sub main_web_app {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $bot, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, bot_user_id', $chat, $bot);
    $self->send({
        '@type'          => 'getMainWebApp',
        chat_id          => 0 + $chat,
        bot_user_id      => 0 + $bot,
        start_parameter  => $opt{start_parameter} // '',
        parameters       => _open_params($self, \%opt),
    }, $cb);
    return;
}

sub web_app_placeholder {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, @rest) = @args;
    _need('bot_user_id', $bot);
    $self->send({ '@type' => 'getWebAppPlaceholder', bot_user_id => 0 + $bot }, $cb);
    return;
}

# an empty url is only valid for an attachment menu bot; otherwise pass the
# url from a WebApp button or TDLib answers BOT_INVALID
sub open_web_app {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat, $bot, $url, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, bot_user_id', $chat, $bot);
    $self->send({
        '@type'      => 'openWebApp',
        chat_id      => 0 + $chat,
        bot_user_id  => 0 + $bot,
        url          => defined $url ? "$url" : '',
        parameters   => _open_params($self, \%opt),
    }, $cb);
    return;
}

sub close_web_app {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($launch_id, @rest) = @args;
    _need('web_app_launch_id', $launch_id);
    $self->send({ '@type' => 'closeWebApp',
                  web_app_launch_id => "$launch_id" }, $cb);
    return;
}

sub send_web_app_data {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $button_text, $data, @rest) = @args;
    _need('bot_user_id, button_text, data', $bot, $button_text, $data);
    $self->send({ '@type' => 'sendWebAppData', bot_user_id => 0 + $bot,
                  button_text => "$button_text", data => "$data" }, $cb);
    return;
}

sub web_app_request {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($bot, $method, $params, @rest) = @args;
    _need('bot_user_id, method, parameters', $bot, $method, $params);
    $self->send({ '@type' => 'sendWebAppCustomRequest', bot_user_id => 0 + $bot,
                  method => "$method", parameters => "$params" }, $cb);
    return;
}

sub answer_web_app_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($query_id, $result, @rest) = @args;
    _need('web_app_query_id, result', $query_id, $result);
    $self->send({ '@type' => 'answerWebAppQuery',
                  web_app_query_id => "$query_id", result => $result }, $cb);
    return;
}

sub on_web_app_data {
    my ($self, $cb) = @_;
    $self->{on_web_app_data} = $cb if $cb;
    return $self->{on_web_app_data};
}

1;
