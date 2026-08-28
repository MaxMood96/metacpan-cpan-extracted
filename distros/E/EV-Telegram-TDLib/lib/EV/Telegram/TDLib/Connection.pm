package EV::Telegram::TDLib::Connection;

use strict;
use warnings;
use Carp ();

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES = (
    updateConnectionState => \&_update_connection_state,
    updateOption          => \&_update_option,
);

# TDLib pushes its options as updates, my_id among them right after login,
# so the account's own id is known without a getMe round trip
sub _update_option {
    my ($self, $obj) = @_;
    my $name = $obj->{name};
    return unless defined $name;
    my $v = $obj->{value} // {};
    my $type = $v->{'@type'} // '';
    $self->{cache}{options}{$name} =
          $type eq 'optionValueEmpty' ? undef
        : $type eq 'optionValueBoolean' ? ($v->{value} ? 1 : 0)
        : $v->{value};
}

sub option {
    my ($self, $name) = @_;
    return $self->{cache}{options}{$name};
}

sub my_id { $_[0]{cache}{options}{my_id} }

sub _update_connection_state {
    my ($self, $obj) = @_;
    my $state = $obj->{state} or return;
    my $type = $state->{'@type'} // '';
    return unless length $type;
    $self->{cache}{connection_state} = $type;
    if (my $cb = $self->{on_connection_state}) { $cb->($type) }
}

sub connection_state { $_[0]{cache}{connection_state} }

sub on_connection_state {
    my ($self, $cb) = @_;
    $self->{on_connection_state} = $cb if $cb;
    return $self->{on_connection_state};
}

sub sessions {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getActiveSessions' }, $cb);
    return;
}

# session ids are TL int64 and must not cross as numbers
sub terminate_session {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($session_id, @rest) = @args;
    _need('session_id', $session_id);
    $self->send({ '@type' => 'terminateSession',
                  session_id => "$session_id" }, $cb);
    return;
}

sub terminate_other_sessions {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'terminateAllOtherSessions' }, $cb);
    return;
}

sub set_session_ttl {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($days, @rest) = @args;
    _need('inactive_session_ttl_days', $days);
    $self->send({ '@type' => 'setInactiveSessionTtl',
                  inactive_session_ttl_days => 0 + $days }, $cb);
    return;
}


my %PROXY_TYPE = (
    socks5  => 'proxyTypeSocks5',
    http    => 'proxyTypeHttp',
    mtproto => 'proxyTypeMtproto',
);

sub _proxy {
    my ($spec) = @_;
    Carp::croak('a proxy needs a hashref') unless ref $spec eq 'HASH';
    my $kind = $spec->{type} // 'socks5';
    my $t = $PROXY_TYPE{$kind} or Carp::croak("unknown proxy type '$kind'");
    my %type = ('@type' => $t);
    if ($kind eq 'mtproto') { $type{secret} = $spec->{secret} // '' }
    else {
        $type{username} = $spec->{username} // '';
        $type{password} = $spec->{password} // '';
        $type{http_only} = EV::Telegram::TDLib::_json_bool($spec->{http_only})
            if $kind eq 'http';
    }
    return { '@type' => 'proxy', server => $spec->{server} // '',
             port => 0 + ($spec->{port} // 0), type => \%type };
}

sub add_proxy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($spec, @rest) = @args;
    my %opt = @rest;
    _need('proxy', $spec);
    $self->send({ '@type' => 'addProxy', proxy => _proxy($spec),
                  enable => EV::Telegram::TDLib::_json_bool(
                      exists $opt{enable} ? $opt{enable} : 1),
                  comment => $opt{comment} // '' }, $cb);
    return;
}

sub proxies {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getProxies' }, $cb);
    return;
}

sub enable_proxy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($proxy_id, @rest) = @args;
    _need('proxy_id', $proxy_id);
    $self->send({ '@type' => 'enableProxy', proxy_id => 0 + $proxy_id }, $cb);
    return;
}

sub disable_proxy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'disableProxy' }, $cb);
    return;
}

sub remove_proxy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($proxy_id, @rest) = @args;
    _need('proxy_id', $proxy_id);
    $self->send({ '@type' => 'removeProxy', proxy_id => 0 + $proxy_id }, $cb);
    return;
}

sub ping_proxy {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($spec, @rest) = @args;
    _need('proxy', $spec);
    $self->send({ '@type' => 'pingProxy', proxy => _proxy($spec) }, $cb);
    return;
}

my %NETWORK = (
    none    => 'networkTypeNone',
    mobile  => 'networkTypeMobile',
    roaming => 'networkTypeMobileRoaming',
    wifi    => 'networkTypeWiFi',
    other   => 'networkTypeOther',
);

# telling TDLib the network changed lets it reconnect promptly instead of
# waiting for its own timers
sub set_network_type {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($type, @rest) = @args;
    my $t = $NETWORK{ $type // '' }
        or Carp::croak("unknown network type '" . ($type // '') . "'");
    $self->send({ '@type' => 'setNetworkType', type => { '@type' => $t } }, $cb);
    return;
}

sub network_statistics {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    $self->send({ '@type' => 'getNetworkStatistics',
                  only_current => EV::Telegram::TDLib::_json_bool($opt{current}) }, $cb);
    return;
}

sub log_out {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'logOut' }, $cb);
    return;
}

sub password_state {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    $self->send({ '@type' => 'getPasswordState' }, $cb);
    return;
}

sub set_password {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($old, $new, @rest) = @args;
    my %opt = @rest;
    $self->send({
        '@type'        => 'setPassword',
        old_password   => defined $old ? "$old" : '',
        new_password   => defined $new ? "$new" : '',
        new_hint       => $opt{hint} // '',
        set_recovery_email_address =>
            EV::Telegram::TDLib::_json_bool(defined $opt{recovery_email}),
        new_recovery_email_address => $opt{recovery_email} // '',
    }, $cb);
    return;
}

# the account is deleted after this many days with no activity
sub account_ttl {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($days, @rest) = @args;
    return $self->send({ '@type' => 'getAccountTtl' }, $cb) unless defined $days;
    $self->send({ '@type' => 'setAccountTtl',
                  ttl => { '@type' => 'accountTtl', days => 0 + $days } }, $cb);
    return;
}

sub register_device {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($token, @rest) = @args;
    my %opt = @rest;
    _need('device_token', $token);
    Carp::croak('register_device needs a deviceToken hashref')
        unless ref $token eq 'HASH';
    $self->send({ '@type' => 'registerDevice', device_token => $token,
                  other_user_ids =>
                      [ map { 0 + $_ } @{ $opt{other_users} || [] } ] }, $cb);
    return;
}

1;
