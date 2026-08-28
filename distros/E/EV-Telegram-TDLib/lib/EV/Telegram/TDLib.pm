package EV::Telegram::TDLib;

use strict;
use warnings;
use Carp qw(croak);
use EV;
use Cpanel::JSON::XS;
use XSLoader;
use EV::Telegram::TDLib::Users;
use EV::Telegram::TDLib::Chats;
use EV::Telegram::TDLib::Messages;
use EV::Telegram::TDLib::Files;
use EV::Telegram::TDLib::Connection;
use EV::Telegram::TDLib::Bots;
use EV::Telegram::TDLib::WebApps;
use EV::Telegram::TDLib::Forum;
use EV::Telegram::TDLib::Folders;
use EV::Telegram::TDLib::Payments;
use EV::Telegram::TDLib::Secret;
use EV::Telegram::TDLib::Schema;

our $VERSION = '0.03';

our @ISA = map { "EV::Telegram::TDLib::$_" }
    qw(Users Chats Messages Files Connection Bots WebApps Forum Folders Payments
       Secret);

XSLoader::load('EV::Telegram::TDLib', $VERSION);

sub CLONE_SKIP { 1 }

my $JSON = Cpanel::JSON::XS->new->utf8->canonical(0)->allow_nonref;

my %CLIENTS;

sub execute {
    my ($proto, $request) = @_;
    my $json = _execute($JSON->encode($request));
    return undef unless defined $json;
    return $JSON->decode($json);
}

sub _set_log_verbosity {
    my ($level) = @_;
    _execute($JSON->encode({
        '@type' => 'setLogVerbosityLevel',
        new_verbosity_level => $level,
    }));
}

_set_log_verbosity($ENV{TDLIB_LOG_VERBOSITY} // 1);

sub login {
    my ($self, $cb) = @_;
    $cb ||= sub {};
    # tdjson creates the client, and emits its first update, only once a request
    # reaches it; the auth flow is driven entirely by updateAuthorizationState,
    # so without this a fresh client waits forever
    $self->send({ '@type' => 'getAuthorizationState' }, sub {})
        if ($self->{state} // '') eq 'created' && !$self->{kicked}++;
    my $state = $self->{state} // '';
    if ($state ne 'authorizationStateReady'
            && $state ne 'authorizationStateClosed'
            && !$self->{login_failed}) {
        # chain, never replace: close() has the same contract
        push @{ $self->{login_cbs} }, $cb;
        return;
    }
    # fire deferred, never inline: an inconsistently timed callback is worse
    my $err = $state eq 'authorizationStateReady'  ? undef
            : $state eq 'authorizationStateClosed' ? 'client is already closed'
            : $self->{login_failed};
    push @{ $self->{login_late} }, [ $cb, $err ];
    $self->{login_deferred} ||= EV::timer 0, 0, sub {
        delete $self->{login_deferred};
        for my $late (@{ delete $self->{login_late} || [] }) {
            my ($cb, $err) = @$late;
            $self->_guarded($cb, undef,
                $err ? { '@type' => 'error', code => -1, message => $err }
                     : undef);
        }
    };
    return;
}

sub auth_state { shift->{state} }

sub _fail_login {
    my ($self, $message) = @_;
    # the FSM never re-emits a failed state, so a later login() must fail fast
    $self->{login_failed} //= $message;
    my $cbs = delete $self->{login_cbs};
    if ($cbs) {
        $self->_guarded($_, undef, { '@type' => 'error', code => -1,
                                     message => $message }) for @$cbs;
    } else {
        $self->_emit_error($message);
    }
}

# only a correlated error matters, and only while the FSM is still in that state
sub _auth_reply_cb {
    my ($self, $stype, $on_error) = @_;
    return sub {
        my ($res, $err) = @_;
        return unless $err;
        return unless $self->{client_id};
        return if ($self->{state} // '') ne $stype;
        $on_error->($err);
    };
}

# automatic steps take constructor values: no interactive retry path
sub _auth_fail_cb {
    my ($self, $stype, $what) = @_;
    return $self->_auth_reply_cb($stype, sub {
        my ($err) = @_;
        $self->_fail_login("$what: $err->{message}");
    });
}

sub _json_bool { $_[0] ? \1 : \0 }

# a missing required argument must fail at the call site: passing it on
# would warn from inside the module and send TDLib a malformed request
sub _need {
    my ($what, @args) = @_;
    for my $i (0 .. $#args) {
        next if defined $args[$i];
        my @names = split /,\s*/, $what;
        croak(($names[$i] // 'argument') . ' is required');
    }
    return 1;
}

# 429 carries its delay only in the message text; see the rate-limiting
# section in the POD for why no retry happens here
sub retry_after {
    my ($self, $err) = @_;
    $err = $self unless defined $err;   # usable as method or plain function
    return undef unless ref $err eq 'HASH';
    return undef unless ($err->{code} // 0) == 429;
    my ($n) = ($err->{message} // '') =~ /retry after ([0-9]+)/i;
    return defined $n ? 0 + $n : undef;
}

my %UPDATE_HANDLERS = (
    %EV::Telegram::TDLib::Users::UPDATES,
    %EV::Telegram::TDLib::Chats::UPDATES,
    %EV::Telegram::TDLib::Messages::UPDATES,
    %EV::Telegram::TDLib::Files::UPDATES,
    %EV::Telegram::TDLib::Connection::UPDATES,
    %EV::Telegram::TDLib::Bots::UPDATES,
    %EV::Telegram::TDLib::WebApps::UPDATES,
    %EV::Telegram::TDLib::Forum::UPDATES,
    %EV::Telegram::TDLib::Folders::UPDATES,
    %EV::Telegram::TDLib::Payments::UPDATES,
    %EV::Telegram::TDLib::Secret::UPDATES,
);

sub _handle_update {
    my ($self, $obj) = @_;
    my $type = $obj->{'@type'} // '';
    $self->_auth_update($obj) if $type eq 'updateAuthorizationState';
    if (my $h = $UPDATE_HANDLERS{$type}) { $h->($self, $obj) }
    if (my $cb = $self->{on_update}) { $cb->($obj); }
}

sub _auth_update {
    my ($self, $obj) = @_;
    my $state = $obj->{authorization_state} // {};
    my $stype = $state->{'@type'} // '';
    $self->{state} = $stype;

    # lifecycle continuations run even with auto_auth off
    if ($stype eq 'authorizationStateReady') {
        if (my $cbs = delete $self->{login_cbs}) {
            $self->_guarded($_, undef, undef) for @$cbs;
        }
        return;
    }
    if ($stype eq 'authorizationStateClosed') {
        $self->_closed;
        return;
    }
    return unless $self->{auto_auth};

    if ($stype eq 'authorizationStateWaitTdlibParameters') {
        $self->_auth_parameters;
    }
    elsif ($stype eq 'authorizationStateWaitPhoneNumber') {
        my $opt = $self->{opt};
        if ($opt->{bot_token}) {
            $self->send({ '@type' => 'checkAuthenticationBotToken',
                          token => $opt->{bot_token} },
                        $self->_auth_fail_cb($stype, 'checkAuthenticationBotToken'));
        } elsif ($opt->{on_qr} && !$opt->{phone_number}) {
            $self->send({ '@type' => 'requestQrCodeAuthentication' },
                        $self->_auth_fail_cb($stype, 'requestQrCodeAuthentication'));
        } else {
            $self->send({ '@type' => 'setAuthenticationPhoneNumber',
                          phone_number => $opt->{phone_number} },
                        $self->_auth_fail_cb($stype, 'setAuthenticationPhoneNumber'));
        }
    }
    elsif ($stype eq 'authorizationStateWaitEmailAddress') {
        $self->_auth_credential(on_email => $stype, $state,
            sub { +{ '@type' => 'setAuthenticationEmailAddress',
                     email_address => $_[0] } });
    }
    elsif ($stype eq 'authorizationStateWaitEmailCode') {
        $self->_auth_credential(on_email_code => $stype, $state,
            sub { +{ '@type' => 'checkAuthenticationEmailCode',
                     code => { '@type' => 'emailAddressAuthenticationCode',
                               code => $_[0] } } });
    }
    elsif ($stype eq 'authorizationStateWaitCode') {
        $self->_auth_credential(on_code => $stype, $state->{code_info},
            sub { +{ '@type' => 'checkAuthenticationCode', code => $_[0] } });
    }
    elsif ($stype eq 'authorizationStateWaitRegistration') {
        my $reg = $self->{opt}{register};
        if (ref $reg eq 'HASH' && $reg->{first_name}) {
            $self->send({ '@type' => 'registerUser',
                          first_name => $reg->{first_name},
                          last_name  => $reg->{last_name} // '',
                          disable_notification => _json_bool(0) },
                        $self->_auth_fail_cb($stype, 'registerUser'));
        } else {
            $self->_fail_login("$stype reached but no register option was given");
        }
    }
    elsif ($stype eq 'authorizationStateWaitPassword') {
        $self->_auth_credential(on_password => $stype, $state,
            sub { +{ '@type' => 'checkAuthenticationPassword', password => $_[0] } });
    }
    elsif ($stype eq 'authorizationStateWaitOtherDeviceConfirmation') {
        if (my $cb = $self->{on_qr}) {
            $cb->($state->{link});
        } else {
            $self->_fail_login("$stype reached but no on_qr callback was given");
        }
    }
    elsif ($stype eq 'authorizationStateWaitPremiumPurchase') {
        $self->_fail_login("$stype cannot be satisfied programmatically");
    }
}

# _closed can only ever run once: a dying callback must not skip the rest
sub _guarded {
    my ($self, $cb, @args) = @_;
    eval { $cb->(@args); 1 } or do {
        my $e = $@ || 'unknown error';
        chomp $e;
        # a dying on_error must not unwind the chain either
        eval { $self->_emit_error("a callback died: $e") };
    };
}

sub _closed {
    my ($self) = @_;
    my $cid = delete $self->{client_id} or return;
    delete $CLIENTS{$cid};
    # each credential submitter is a closure that refers to itself and
    # captures $self; clearing the pad slot is what frees the client
    for my $slot (@{ delete $self->{auth_submits} || [] }) { undef $$slot }
    # keepalive(0) already spent this ref; unref-ing twice steals another client's
    if ($self->{keepalive} // 1) {
        _pump_unref();
        $self->{keepalive} = 0;
    }
    for my $extra (keys %{ $self->{pending} }) {
        my $p = delete $self->{pending}{$extra};
        $p->{timer}->stop if $p->{timer};
        $self->_guarded($p->{cb}, undef, { '@type' => 'error', code => -1,
                                           message => 'client closed' });
    }
    for my $cb (values %{ delete $self->{cache}{sending} // {} }) {
        $self->_guarded($cb, undef, { '@type' => 'error', code => -1,
                                      message => 'client closed' });
    }
    for my $dl (values %{ delete $self->{cache}{downloads} // {} }) {
        $self->_guarded($dl->{cb}, undef, { '@type' => 'error', code => -1,
                                            message => 'client closed' });
    }
    # upload watchers are progress-only: no completion promise, nothing to fail
    delete $self->{cache}{uploads};
    if (my $cbs = delete $self->{login_cbs}) {
        $self->_guarded($_, undef, { '@type' => 'error', code => -1,
                                     message => 'client closed during login' })
            for @$cbs;
    }
    if (my $cbs = delete $self->{close_cbs}) { $self->_guarded($_) for @$cbs }
    if (my $cb = $self->{on_close}) { $self->_guarded($cb) }
}

sub close {
    my ($self, $cb) = @_;
    $cb ||= sub {};
    if (($self->{state} // '') eq 'authorizationStateClosed') {
        # deferred and chained, as login()
        push @{ $self->{close_late} }, $cb;
        $self->{close_deferred} ||= EV::timer 0, 0, sub {
            delete $self->{close_deferred};
            my $cbs = delete $self->{close_late} || [];
            $self->_guarded($_) for @$cbs;
        };
        return;
    }
    # chain, not replace; TDLib needs the close request only once
    my $first = !$self->{close_cbs};
    push @{ $self->{close_cbs} }, $cb;
    $self->send({ '@type' => 'close' }) if $first;
    return;
}

sub _is_registered {
    my ($client_id) = @_;
    return $CLIENTS{$client_id} ? 1 : 0;
}

sub DESTROY {
    my ($self) = @_;
    # close() needs client_id; deleting it here would address client 0
    my $cid = $self->{client_id} or return;
    return unless $CLIENTS{$cid};
    eval { $self->close() };
}

sub _auth_credential {
    my ($self, $handler, $stype, $info, $make_request) = @_;
    my $cb = $self->{$handler};
    if (!$cb) {
        $self->_fail_login("$stype reached but no $handler callback was given");
        return;
    }
    # $submit has to refer to itself so a rejected credential can be asked
    # for again, and that cycle captures $self. Nothing collects it, so the
    # client would outlive its own close: keep a handle and clear it there.
    my $submit;
    $submit = sub {
        my ($value) = @_;
        # TDLib stays in the state on rejection: ask again, with the error
        $self->send($make_request->($value), $self->_auth_reply_cb($stype, sub {
            my ($err) = @_;
            $cb->($info, $submit, $err) if $err;
        }));
    };
    push @{ $self->{auth_submits} }, \$submit;
    $cb->($info, $submit);
}

sub _auth_parameters {
    my ($self) = @_;
    my $opt = $self->{opt};
    my $dbdir = $opt->{database_directory} // 'tdlib-db';
    $self->send({
        '@type' => 'setTdlibParameters',
        use_test_dc             => _json_bool($opt->{use_test_dc}),
        database_directory      => $dbdir,
        files_directory         => $opt->{files_directory} // $dbdir,
        database_encryption_key => $opt->{database_encryption_key} // '',
        use_file_database       => _json_bool($opt->{use_file_database} // 1),
        use_chat_info_database  => _json_bool($opt->{use_chat_info_database} // 1),
        use_message_database    => _json_bool($opt->{use_message_database} // 1),
        use_secret_chats        => _json_bool($opt->{use_secret_chats} // 1),
        api_id                  => 0 + ($opt->{api_id} // 0),
        api_hash                => $opt->{api_hash} // '',
        system_language_code    => $opt->{system_language_code} // 'en',
        device_model            => $opt->{device_model} // 'EV::Telegram::TDLib',
        system_version          => $opt->{system_version} // $^O,
        application_version     => $opt->{application_version} // $VERSION,
    }, $self->_auth_fail_cb('authorizationStateWaitTdlibParameters',
                            'setTdlibParameters'));
}

sub new {
    my ($class, %opt) = @_;
    my $self = bless {
        json      => Cpanel::JSON::XS->new->utf8->allow_nonref,
        seq       => 0,
        pending   => {},
        abandoned => {},
        cache     => {},
        opt       => \%opt,
        auto_auth => exists $opt{auto_auth} ? $opt{auto_auth} : 1,
        state     => 'created',
    }, $class;

    $self->{$_} = $opt{$_} for grep { /^on_/ } keys %opt;
    $self->{application_name} = EV::Telegram::TDLib::WebApps::_check_application_name(
        $opt{application_name} // 'tdesktop');
    $self->{client_id} = _create_client_id();
    $CLIENTS{ $self->{client_id} } = $self;
    _pump_ref();
    return $self;
}

sub on_update {
    my ($self, $cb) = @_;
    $self->{on_update} = $cb if $cb;
    return $self->{on_update};
}

sub on_error {
    my ($self, $cb) = @_;
    $self->{on_error} = $cb if $cb;
    return $self->{on_error};
}

sub _emit_error {
    my ($self, $message) = @_;
    if (my $cb = $self->{on_error}) {
        $cb->($message);
    } else {
        warn "EV::Telegram::TDLib: $message\n";
    }
}

# must never die: the C drain has no frame to unwind into, and would leak the batch
sub _drain_error {
    my ($client_id, $message) = @_;
    my $self = $CLIENTS{$client_id};
    return if $self && eval { $self->_emit_error($message); 1 };
    eval { warn "EV::Telegram::TDLib: $message\n" };
}

sub _dispatch_raw {
    my ($client_id, $json) = @_;
    my $self = $CLIENTS{$client_id} or return;
    my $obj  = eval { $self->{json}->decode($json) };
    if (!defined $obj) {
        $self->_emit_error("cannot decode TDLib response: $@");
        return;
    }
    # allow_nonref means a bare scalar or an array decodes fine; every real
    # TDLib payload is an object, and treating anything else as one dies
    if (ref $obj ne 'HASH') {
        $self->_emit_error('TDLib response is not an object: '
            . (ref $obj ? lc ref $obj : 'scalar'));
        return;
    }
    my $extra = delete $obj->{'@extra'};
    delete $obj->{'@client_id'};

    if (defined $extra) {
        my $p = delete $self->{pending}{$extra};
        if ($p) {
            $p->{timer}->stop if $p->{timer};
            my $is_err = ($obj->{'@type'} // '') eq 'error';
            $p->{cb}->($is_err ? (undef, $obj) : ($obj, undef));
            return;
        }
        if (delete $self->{abandoned}{$extra}) {
            warn "EV::Telegram::TDLib: late reply for timed-out request $extra\n";
            return;
        }
        # an unknown @extra is a reply, not an update
        warn "EV::Telegram::TDLib: reply for unknown request $extra dropped\n";
        return;
    }
    $self->_handle_update($obj);
}

_set_dispatch(\&_dispatch_raw);

sub send {
    my ($self, $request, $cb, %opt) = @_;
    # a closed client has no client_id: _send would address client 0 and
    # the pending entry could never be flushed, so fail deferred instead
    if (!$self->{client_id}) {
        if ($cb) {
            my $w; $w = EV::timer 0, 0, sub {
                undef $w;
                $cb->(undef, { '@type' => 'error', code => -1,
                               message => 'client is closed' });
            };
        }
        return undef;
    }
    my $extra = ++$self->{seq};
    my %req = (%$request, '@extra' => "$extra");
    # encode before registering anything: an unencodable request croaks, and
    # a pending entry left behind would later fire a timeout for a request
    # that was never sent, failing the same call twice through two channels
    my $payload = $self->{json}->encode(\%req);
    $self->{pending}{$extra} = { cb => $cb || sub {} };
    if (my $t = $opt{timeout}) {
        # ev_now may be seconds stale after the process blocked outside
        # the loop: without a refresh a fresh short timeout fires at once
        EV::now_update();
        $self->{pending}{$extra}{timer} = EV::timer $t, 0, sub {
            my $p = delete $self->{pending}{$extra} or return;
            $self->_abandon($extra);
            $p->{cb}->(undef, {
                '@type' => 'error', code => -1, message => 'timeout',
            });
        };
    }
    _send($self->{client_id}, $payload);
    return $extra;
}

sub _abandon {
    my ($self, $extra) = @_;
    $self->{abandoned}{$extra} = 1;
    if (keys %{ $self->{abandoned} } > 1000) {
        my ($oldest) = sort { $a <=> $b } keys %{ $self->{abandoned} };
        delete $self->{abandoned}{$oldest};
    }
}

# a validated sibling of send: an unknown function passes straight through so
# a newer TDLib keeps working, but a typo in a known one is caught here
# instead of coming back as an opaque server error
sub call {
    my ($self, $function, $args, $cb) = @_;
    _need('function', $function);
    $args //= {};
    croak 'call needs a hashref of arguments' unless ref $args eq 'HASH';
    if (defined(my $known = $EV::Telegram::TDLib::Schema::FUNCTIONS{$function})) {
        my %valid = map { $_ => 1 } split ' ', $known;
        for my $k (sort keys %$args) {
            next if $k eq '@type' || $valid{$k};
            croak "unknown argument '$k' for $function; valid arguments are: "
                . (length $known ? $known : '(none)');
        }
    }
    return $self->send({ %$args, '@type' => "$function" }, $cb);
}

sub _inject_raw {
    my ($self, $json) = @_;
    _dispatch_raw($self->{client_id}, $json);
}

sub keepalive {
    my ($self, $on) = @_;
    # normalise first: an unnormalised truthy value compares unequal to the
    # stored 1, takes a second loop ref, and the loop is never released
    $on = defined $on ? ($on ? 1 : 0) : 1;
    my $cur = $self->{keepalive} // 1;
    # a closed client holds no loop ref: spending or taking one here
    # would corrupt the pump accounting for the clients still open
    return $cur if !$self->{client_id} || $on == $cur;
    $self->{keepalive} = $on;
    $on ? _pump_ref() : _pump_unref();
    return $on;
}

# close every still-open client and pump the loop for a bounded interval
# so TDLib flushes its database, then join the reader before TDLib's
# statics are torn down; evals keep a forked child's poison croaks from
# changing its exit status
END {
    eval {
        $_->close() for values %CLIENTS;
        if (%CLIENTS) {
            # compare against the watchdog flag, never the wall clock:
            # libev schedules the timer against its cached ev_now, so the
            # wake can land before EV::time reaches the deadline, and a
            # re-entered RUN_ONCE with no events left blocks forever
            my $timed_out = 0;
            # giving up here tears TDLib's statics down while it is still
            # closing, which can abort; the default is generous for a healthy
            # machine but a sanitizer build or a loaded box needs longer
            my $budget = $ENV{EV_TDLIB_SHUTDOWN_TIMEOUT} || 3;
            my $watchdog = EV::timer $budget, 0, sub { $timed_out = 1; EV::break };
            EV::run(EV::RUN_ONCE) while %CLIENTS && !$timed_out;
            $watchdog->stop;
        }
    };
    eval { EV::Telegram::TDLib::_shutdown() };
}

1;

=head1 NAME

EV::Telegram::TDLib - asynchronous Telegram client on TDLib and EV

=head1 SYNOPSIS

    use EV;
    use EV::Telegram::TDLib;

    my $chat_id = $ENV{TD_CHAT_ID};

    my $td = EV::Telegram::TDLib->new(
        api_id             => $ENV{TD_API_ID},
        api_hash           => $ENV{TD_API_HASH},
        phone_number       => '+10000000000',
        database_directory => 'tdlib-db',
        on_code    => sub {
            my ($info, $submit) = @_;
            print "code from Telegram: ";
            chomp(my $code = <STDIN>);
            $submit->($code);
        },
        on_message => sub {
            my ($msg) = @_;
            print "message $msg->{id} in chat $msg->{chat_id}\n";
        },
        on_error   => sub { warn "tdlib: $_[0]\n" },
    );

    $td->login(sub {
        my (undef, $err) = @_;
        die "login failed: $err->{message}\n" if $err;
        $td->send_message($chat_id, 'hello', sub {
            my ($msg, $err) = @_;
            die "send failed: $err->{message}\n" if $err;
            $td->close(sub { EV::break });
        });
    });

    EV::run;

=head1 DESCRIPTION

EV::Telegram::TDLib binds TDLib's tdjson C interface to the L<EV>
event loop. A dedicated reader thread blocks in td_receive, copies each
JSON result, and wakes the loop through ev_async; the loop decodes,
correlates replies to pending requests by C<@extra>, drives the
authorization state machine, maintains user and chat caches, and calls
your handlers.

Asynchronous callbacks follow the family idiom: they receive
C<($result, $err)> where C<$err> is undef on success and a decoded
TDLib error object on failure. A TDLib error is never thrown; see
L</CONVENTIONS> for what does croak.

Requires a perl with 64-bit integers: Telegram ids are int64 and
message ids are shifted left by 20 bits, so they must never round-trip
through an NV. The Makefile refuses to build otherwise.

The bundled TDLib is 1.8.66, pinned by Alien::TDLib at commit
022d60202e446ad1287b9fb68e687c8a0760788b.

=head1 CONSTRUCTOR

=head2 new(%opt)

Creates a client and registers it in a process-global registry. The
client is held under a strong reference until close() completes; see
L</CAVEATS>. Options:

=over 4

=item api_id, api_hash

Telegram application credentials from https://my.telegram.org. Keep
them in the environment, not in source; see L</SECURITY>.

=item phone_number

Phone number in international format for user authorization. Used
when the state machine reaches authorizationStateWaitPhoneNumber,
unless bot_token is present. Setting on_qr as well does not override
it: a QR link is requested only when on_qr is set and no phone_number
was given.

=item bot_token

Bot token from BotFather. When present it is sent automatically at
authorizationStateWaitPhoneNumber and no further credential callbacks
are needed.

=item database_directory

Session and database directory. Default C<tdlib-db>. See L</SECURITY>.

=item files_directory

Downloaded files directory. Defaults to database_directory.

=item database_encryption_key

Encryption key for the local database. Empty by default; set it.

=item use_test_dc

Use the Telegram test data centers instead of production. Always set
this in tests.

=item use_file_database, use_chat_info_database, use_message_database, use_secret_chats

TDLib feature switches, all defaulting to true.

=item application_name

The platform identifier sent with every Mini App request, which the app
receives as C<tgWebAppPlatform>. Defaults to C<tdesktop>. See
L</MINI APPS> for why the value matters and what it may contain.

=item system_language_code, device_model, system_version, application_version

Client identification sent with setTdlibParameters. Defaults: C<en>,
C<EV::Telegram::TDLib>, C<$^O>, this distribution's version.

=item auto_auth

Drive the authorization state machine automatically (default true).
With auto_auth false, only the login and close lifecycle continuations
run; every credential step is left to you via send().

=item register

Hashref C<{ first_name =E<gt> ..., last_name =E<gt> ... }>. When set,
authorizationStateWaitRegistration is answered with registerUser;
without it the state fails login.

=item on_update, on_error, on_close, on_user, on_chat, on_message, on_connection_state

Update handlers; see L</UPDATES> and the mixin methods below.

=item on_code, on_password, on_email, on_email_code, on_qr

Authorization credential callbacks; see L</AUTHORIZATION>.

=back

=head1 CONVENTIONS

Three patterns run through the whole interface. Knowing them saves reading
300 method signatures.

=head2 Cache readers against remote getters

L</chat($chat_id)> and L</user($user_id)> are B<synchronous cache reads>:
they take no callback, do no I/O, and return undef for something the
client has not seen. Everything else named after a noun -- C<folder>,
C<topic>, C<secret_chat>, C<supergroup>, C<basic_group>, C<message>,
C<file> -- is an B<asynchronous getter> that takes a callback and asks
TDLib.

The two cache readers predate the rest and are kept as they are because
renaming a method already published on CPAN would break working code.
When you want the server's answer for a chat rather than the cached one,
use L</fetch_chat($chat_id, $cb)>.

=head2 Booleans

A method that turns something on or off takes the flag as its last
positional argument and B<defaults to true>, so C<pin_topic($chat, $id)>
pins and C<pin_topic($chat, $id, 0)> unpins. That covers close_topic,
pin_topic, pin_chat, mark_unread, hide_general_topic, folder_tags,
pause_download, protect_content, the supergroup switches, and the
process_join_request pair.

Two older methods invert through an option instead
(C<< block_user($id, unblock => 1) >>, C<< react(..., remove => 1) >>),
and a few pairs are separate methods where the two directions differ in
more than a flag: C<mute>/C<unmute>, C<archive>/C<unarchive>,
C<enable_proxy>/C<disable_proxy>.

=head2 Identifiers

TL C<int64> values cross the JSON interface as strings, because a number
would lose precision above 2**53. This module does that for you, and
hands them back as strings: session ids, callback and inline query ids,
profile photo ids, custom emoji ids and Web App launch ids are all
strings you should keep as strings. Chat, message and user ids are
C<int53> and stay numbers.

=head1 METHODS

=head2 Core

=head3 send(\%request, $cb, %opt)

Encodes the request, assigns a fresh C<@extra>, and hands it to TDLib.
The reply is delivered as C<< $cb->($result, $err) >>. Returns the
assigned C<@extra> sequence number.

send() deliberately overwrites any caller-supplied C<@extra>: it is
the reply correlation channel, and a collision would misroute a reply
to the wrong callback.

Option: C<timeout> in seconds. A timed-out request fails its callback
with a synthetic error; the late reply, if it ever arrives, is dropped
with a warning, never delivered to a reused C<@extra>. See
L</ERROR HANDLING>.

On a closed client send() sends nothing, registers nothing and returns
undef: the callback is failed deferred with a synthetic
C<client is closed> error.

=head3 execute(\%request)

Synchronous td_execute. No network, usable before authorization, and
usable as a class method as well as an instance method:

    my $me = EV::Telegram::TDLib->execute({ '@type' => 'getMe' });

Only the TDLib methods documented as synchronous return a meaningful
result here; anything else returns undef or an error.

=head3 login($cb)

Completes when the authorization state machine (see L</AUTHORIZATION>)
reaches authorizationStateReady: C<< $cb->(undef, undef) >>. On
failure the callback receives a decoded or synthetic error. The
callback never fires synchronously, even when the state is already
settled. Calling login() again before Ready chains the callbacks, as
with close(); none is dropped. A login that has already failed fails a
later login() deferred with the recorded error instead of hanging: the
state machine stays in the failed state and never re-emits it.

=head3 auth_state()

Returns the last seen authorization state name.

=head3 close($cb)

Sends C<{"@type":"close"}> and calls C<$cb> once
authorizationStateClosed arrives. close() is not optional; see
L</CAVEATS>. Calling close() a second time before Closed is legal: the
callbacks chain and none is dropped.

=head3 keepalive([$on])

An open client holds an ev_ref on the default loop so EV::run does not
return while TDLib traffic is pending. keepalive(0) releases it, so the
loop may exit with the client still open. Defaults to on. The reference
is accounted per client: close() releases it only while still held, and
keepalive() on a closed client is a no-op that returns off.

=head3 on_update($cb), on_error($cb)

Get or set the generic update and error handlers. on_error receives
non-fatal internal errors (undecodable frames, callback exceptions);
without it they go to warn.

=head3 retry_after($err)

Returns the delay in seconds that a 429 error asks for, parsed out of
its message text, or undef for any other error or when no delay is
stated. Usable as a method or a plain function. See
L</"Rate limiting: error code 429">; the module still performs no
retry of its own.

=head3 call($function, \%args, $cb)

Sends a raw request like L</send(\%request, $cb, %opt)>, but checks the
argument names first against a catalogue of every TDLib function,
generated from the C<td_api.h> that L<Alien::TDLib> ships. The C<@type>
is filled in from C<$function>, so it is not repeated.

    $td->call(getChatMember => { chat_id => $c, member_id => $m }, sub {
        my ($member, $err) = @_;
        ...
    });

A typo in a known function's arguments croaks and lists the valid
names. An unknown function is passed straight through, so a TDLib newer
than the shipped catalogue keeps working; a missing argument is not an
error, since TDLib supplies its own defaults. This makes call() a
usable way to reach the roughly 950 functions this module does not wrap
by hand, without losing every check.

send() is unaffected and stays entirely unvalidated.

=head2 Users mixin

=head3 me($cb)

Fetches the current user (getMe) into the user cache and calls
C<< $cb->($user, $err) >>.

=head3 user($id)

Returns the cached user hashref, or undef.

=head3 set_name($first, $last, $cb), set_bio($text, $cb), set_username($name, $cb)

Change the signed-in account's own profile. set_name requires a first
name; the last name is optional. set_username takes the name with or
without a leading at-sign, and an empty string removes it.

These are user-account methods. A bot session is refused them by
TDLib with "The method is not available to bots"; a bot changes its
own profile through the Bots mixin instead.

=head3 set_profile_photo($path, %opt, $cb)

Sets the account's profile photo. C<animation> treats the file as a
video avatar, with C<main_frame_timestamp> (seconds, default 0)
selecting the still frame. C<public> (default on) controls whether
users who cannot see the full profile get this photo. C<$path> may be
an InputFile hashref instead of a path.

Bots do not use this: a bot session is refused it with
BOT_FALLBACK_UNSUPPORTED. See set_bot_photo in the Bots mixin.

=head3 on_user($cb)

Handler for updateUser, called with the decoded user after the cache
is updated.

=head3 user_by_username($name, $cb)

Resolves a public C<@name> to a user, with or without the leading
at-sign. A name that resolves to a channel or a group is reported as
an error saying so, since only a private chat has a user behind it.
Bots are users and resolve normally.

=head3 set_birthdate(%opt, $cb), set_accent_color($color_id, %opt, $cb), profile_photos($user_id, %opt, $cb), delete_profile_photo($photo_id, $cb)

Profile details. set_birthdate takes C<day>, C<month> and an optional
C<year>; calling it with none clears the birthdate. Profile photo ids
are TL C<int64> and are sent as strings.

=head3 contacts($cb), add_contact($user_id, %opt, $cb), remove_contacts(\@user_ids, $cb), search_contacts($query, %opt, $cb), import_contacts(\@contacts, $cb)

The address book. add_contact options are C<first_name>, C<last_name>,
C<phone>, C<note> and C<share_phone>, which offers your own number in
return. import_contacts takes hashrefs of the same shape and is how you
find which of a list of phone numbers are on Telegram; Telegram matches
on the number, so a contact with none is simply not matched.

=head2 Chats mixin

=head3 chat($id)

Returns the cached chat hashref, or undef. The cache is fed by
updateNewChat and kept current by the chat-field updates listed under
L</UPDATES>.

=head3 on_chat($cb)

Handler for updateNewChat, called with the decoded chat.

=head3 load_chats($limit, $cb)

Loads more chats from TDLib (loadChats). TDLib answers with a 404
error once the list is exhausted; that is reported as success, not
failure.

=head3 pin_message($chat_id, $message_id, %opt, $cb), unpin_message($chat_id, $message_id, $cb)

Pins or unpins a message. Options: C<silent> to pin without notifying,
C<only_for_self> to pin it just for you.

=head3 set_chat_title($chat_id, $title, $cb), set_chat_photo($chat_id, $path, %opt, $cb)

Changes a chat's title or photo. set_chat_photo takes the same
C<animation> and C<main_frame_timestamp> options as
L</set_profile_photo($path, %opt, $cb)>.

=head3 add_chat_member($chat_id, $user_id, %opt, $cb)

Adds a user to a chat. C<forward_limit> (default 0) is how many recent
messages they get to see.

=head3 set_member_status($chat_id, $user_id, $status, %opt, $cb)

Sets a member's status: C<member>, C<left> or C<banned>. C<left> is
the plain kick, which leaves them free to come back; C<banned> removes
and blocks them. C<until> is a unix timestamp for a temporary ban or
membership, 0 (the default) meaning forever. An unknown status croaks.

=head3 block_user($user_id, %opt, $cb)

Blocks a user. C<unblock> reverses it, and C<stories> acts on the
stories block list rather than the main one.

=head3 join_chat($chat_id, $cb), leave_chat($chat_id, $cb)

Joins or leaves a chat. joinChat answers with a ChatJoinResult, which
reports a join request awaiting approval as well as a plain success.

=head3 chat_by_username($name, $cb)

Resolves a public username (with or without the leading @) to a chat
via searchPublicChat and caches it.

=head3 mark_read($chat_id, %opt, $cb)

Marks messages read: openChat followed by viewMessages, which TDLib
only honours while the chat is open. C<message_ids> defaults to the
chat's last message, so C<< $td->mark_read($chat_id, sub {}) >> clears
a chat. Fails if nothing is known to mark.

=head3 chat_action($chat_id, $action, $cb)

Sends a chat action, the "typing..." class of indicator. C<$action> is
one of C<typing> (the default), C<upload_document>, C<upload_photo>,
C<upload_video>, C<upload_voice>, C<record_video>, C<record_voice>,
C<cancel>. An unknown action croaks. The indicator expires on its own
after a few seconds, so repeat it while the work lasts.

=head3 member($chat_id, $user_id, $cb), admins($chat_id, $cb), search_members($chat_id, $query, %opt, $cb)

Read a chat's membership. search_members options: C<limit> (default 50)
and C<filter>, one of C<contacts>, C<administrators>, C<members>,
C<restricted>, C<banned>, C<bots>; an unknown filter croaks.

=head3 set_permissions($chat_id, \%permissions, $cb)

Sets the default permissions for ordinary members. TDLib replaces the
whole set, so any permission not named is denied, and this method sends
all of them explicitly rather than leaving the difference implicit.
Valid keys are the chatPermissions fields: C<can_send_basic_messages>,
C<can_send_audios>, C<can_send_documents>, C<can_send_photos>,
C<can_send_videos>, C<can_send_video_notes>, C<can_send_voice_notes>,
C<can_send_polls>, C<can_send_other_messages>, C<can_add_link_previews>,
C<can_react_to_messages>, C<can_edit_tag>, C<can_change_info>,
C<can_invite_users>, C<can_pin_messages>, C<can_create_topics>.

An unrecognised key croaks rather than being ignored: since absence
means denial, a typo would quietly take a right away.

=head3 set_chat_description($chat_id, $text, $cb)

Sets the description shown on a group or channel's profile.

=head3 invite_link($chat_id, %opt, $cb), edit_invite_link($chat_id, $link, %opt, $cb), invite_links($chat_id, %opt, $cb), revoke_invite_link($chat_id, $link, $cb), replace_primary_invite_link($chat_id, $cb), invite_link_members($chat_id, $link, %opt, $cb)

Manage a chat's invite links. Creating and editing accept C<name>,
C<expires> (a Unix time), C<limit> (maximum members) and
C<join_request>, which makes the link produce join requests to approve
instead of admitting people directly; answer those with
L</join_requests($chat_id, %opt, $cb), process_join_request($chat_id, $user_id, $approve, $cb), process_join_requests($chat_id, $approve, %opt, $cb), on_join_request($cb)>. TDLib replaces the whole link on
an edit, so any option not passed reverts to its default: renaming a
link clears its expiry and member limit. invite_links lists them,
filtered by C<creator> and C<revoked>; invite_link_members lists who
joined through one.

=head3 join_requests($chat_id, %opt, $cb), process_join_request($chat_id, $user_id, $approve, $cb), process_join_requests($chat_id, $approve, %opt, $cb), on_join_request($cb)

The other half of a C<join_request> invite link. join_requests lists who is
waiting, filtered by C<link> and C<query> and bounded by C<limit>;
process_join_request answers one, and the plural form answers everyone at
once, optionally only those who used one C<link>. C<$approve> defaults to
true in both, so declining is explicit.

on_join_request is the handler for updateNewChatJoinRequest, called with a
flattened hashref carrying C<chat_id>, C<user_id>, C<date>, C<bio>,
C<invite_link> and C<user_chat_id>.

=head3 check_invite_link($link, $cb), join_by_link($link, $cb)

Inspect or accept an invite link. These take only the link, since the
chat is whatever it points at, and work for a chat you are not in.

=head3 mute($chat_id, $seconds, $cb), unmute($chat_id, $cb)

Silences a chat for a number of seconds, or indefinitely when no
duration is given. Notification settings are a single object in TDLib,
so these send every other field as "use the default" rather than
replacing them; muting will not quietly reset a chat's sound or preview
choices.

=head3 archive($chat_id, $cb), unarchive($chat_id, $cb), pin_chat($chat_id, $pinned, %opt, $cb), mark_unread($chat_id, $unread, $cb)

Chat list housekeeping. The C<$pinned> and C<$unread> flags default to
true, so C<pin_chat($chat)> pins and C<pin_chat($chat, 0)> unpins.
pin_chat takes a C<list> option, since a chat can be pinned separately
in each list.

=head3 chats(%opt, $cb), search_all($query, %opt, $cb)

chats lists a chat list; search_all searches messages across one,
unlike L</search_messages($chat_id, $query, %opt, $cb)>, which searches
inside a single chat. Both take C<list> and C<limit>; search_all also
takes C<offset>, C<min_date> and C<max_date>.

Wherever a C<list> option appears it is C<main> (the default),
C<archive>, or a chat folder id as a number.

=head3 mute_scope($scope, $seconds, %opt, $cb), scope_settings($scope, $cb), reset_notifications($cb)

Notification defaults for a whole class of chat, where C<$scope> is
C<private>, C<groups> or C<channels>. Every scopeNotificationSettings
field is sent outright, and the story behaviour is left alone unless
you say otherwise: C<mute_stories> defaults to off with the default
story sound, and C<show_story_poster> to on. Options: C<preview>,
C<no_pinned>, C<no_mentions>, C<sound_id>, C<mute_stories>,
C<story_sound_id>, C<show_story_poster>. reset_notifications puts
everything back, including per-chat overrides.

=head3 set_chat_reactions($chat_id, $reactions, %opt, $cb)

Chooses which reactions a chat allows. Pass C<'all'> for everything the
chat's tier permits, or an arrayref of emoji to restrict it. Option:
C<max> for how many a single message may carry.

=head3 blocked(%opt, $cb)

Lists blocked senders. Options: C<offset>, C<limit>, and C<stories> to
read the separate list of senders whose stories are hidden.

=head3 add_members($chat_id, \@user_ids, $cb), ban_member($chat_id, $user_id, %opt, $cb), transfer_ownership($chat_id, $user_id, $password, $cb), set_default_admin_rights(\%rights, %opt, $cb)

Bulk membership and ownership. ban_member differs from
L</set_member_status($chat_id, $user_id, $status, %opt, $cb)> in taking
C<revoke>, which also deletes what the banned member already sent, and
C<until> for a temporary ban. transfer_ownership needs the account
password, which Telegram requires for an irreversible act.
set_default_admin_rights sets what a bot asks for when added as an
administrator; C<< channel => 1 >> targets channels rather than groups.

=head3 create_group($title, %opt, $cb), upgrade_to_supergroup($chat_id, $cb), delete_chat($chat_id, $cb), delete_history($chat_id, %opt, $cb)

create_group makes a supergroup by default; C<channel> makes a channel
and C<forum> makes a forum. Passing C<members> instead creates a basic
group, which is a different TDLib call and needs its members up front.
Also takes C<description> and C<auto_delete>. delete_history options:
C<remove_from_list> and C<revoke>, which deletes for everyone rather
than only for you.

=head3 set_slow_mode($chat_id, $seconds, $cb), set_auto_delete($chat_id, $seconds, $cb), set_discussion_group($chat_id, $discussion_chat_id, $cb), protect_content($chat_id, $on, $cb)

Group settings: how often a member may post, how long messages live,
which group holds a channel's comments, and whether forwarding and
saving are blocked. Passing 0 clears the first two.

=head3 make_forum($id, $on, %opt, $cb), sign_messages($id, $on, %opt, $cb), join_by_request($id, $on, %opt, $cb), join_to_send($id, $on, $cb), all_history_available($id, $on, $cb), hide_members($id, $on, $cb), set_supergroup_username($id, $username, $cb)

Supergroup and channel switches. make_forum is what turns an ordinary
supergroup into one that has topics, which
L</create_topic($chat_id, $name, %opt, $cb)> needs.

These take a B<supergroup id>, which is not the chat id you use
everywhere else: a supergroup's chat id is -1000000000000 minus its
supergroup id. Passing either works, because a negative id is converted
for you. The flag defaults to true in all of them.

=head3 fetch_chat($chat_id, $cb), close_chat($chat_id, $cb), user_full_info($user_id, $cb), supergroup($id, %opt, $cb), basic_group($id, %opt, $cb), supergroup_members($id, %opt, $cb), groups_in_common($user_id, %opt, $cb)

Reading chat and user records. fetch_chat asks TDLib, unlike
L</chat($chat_id)>, which reads the module's cache; it also loads a chat
the client has not seen. close_chat releases a chat that
L</mark_read($chat_id, %opt, $cb)> opened, which nothing else does.
C<< full => 1 >> asks supergroup and basic_group for the fuller record.
supergroup_members takes C<filter> (C<recent>, C<contacts>,
C<administrators>, C<restricted>, C<banned>, C<bots>), C<offset> and
C<limit>.

=head3 chat_event_log($chat_id, %opt, $cb), chat_statistics($chat_id, %opt, $cb), pinned_message($chat_id, $cb), clear_action_bar($chat_id, $cb), message_senders($chat_id, $cb), set_message_sender($chat_id, $sender_id, $cb)

The administrator log, with C<query>, C<from_event_id>, C<limit> and
C<users>; channel statistics, with C<dark> for the dark-theme graphs;
the chat's pinned message; and dismissing the bar Telegram shows above a
chat it thinks may be spam.

message_senders lists the identities allowed to post in a chat and
set_message_sender chooses one, which is how an administrator posts as
the channel rather than as themselves. A negative sender id is a chat, a
positive one a user.

=head2 Messages mixin

=head3 send_message($chat_id, $text, %opt, $cb)

Sends a text message.

C<topic> posts into a forum topic, and works on every sending method.
Without it a message goes to the chat's General topic, which is why a
bot answering in a forum must pass the topic it was addressed in.

C<schedule> takes a Unix time and has the server deliver the message
then. Because a scheduled message is not sent now, the confirmation
C<< wait => 'sent' >> waits for would not arrive until its due time, so
C<wait> defaults to C<accepted> when scheduling and asking for C<sent>
explicitly croaks. Read pending ones back with
L</scheduled($chat_id, $cb)>.


TDLib will not send to a chat it has not loaded, and answers
"Chat not found" instead. A chat id taken from an update or from
L</chat_by_username($name, $cb)> is already known; one you constructed
yourself may not be, and that includes your own Saved Messages, whose
chat id is your user id. Open it first with createPrivateChat and send
to the id that returns:

    $td->send({ '@type' => 'createPrivateChat',
                user_id => $me->{id} }, sub {
        my ($chat, $err) = @_;
        die "$err->{message}\n" if $err;
        $td->send_message($chat->{id}, 'note to self', sub { });
    });

Options:

=over 4

=item parse_mode

C<markdown> (MarkdownV2) or C<html>, parsed through the synchronous
parseTextEntities call. Unlike every other error path, a parse error
is delivered synchronously: send_message invokes C<$cb> with the error
before returning, because parseTextEntities never reaches the network.

=item wait

C<sent> (default) fires the callback on final delivery: sendMessage
returns a message with a temporary id, and the real outcome arrives
later as updateMessageSendSucceeded or updateMessageSendFailed keyed
by that id. C<accepted> fires the callback with the temporary message
as soon as TDLib accepts the request.

=item reply_to

Message id to reply to.

=item silent

Send without a notification.

=item disable_preview

Suppress the link preview.

=item reply_markup

A reply markup hashref, as built by
L</inline_keyboard(\@rows)>.

=back

=head3 entity_text($formatted_text, $entity), entity_texts($formatted_text)

Returns the text a formatting entity covers. TDLib measures
C<offset> and C<length> in UTF-16 code units, so C<substr> is wrong
for any text containing a character outside the BMP -- an emoji is one
Perl character but two UTF-16 units, and every entity after it is
shifted. entity_text does the slicing; entity_texts does it for every
entity at once, returning an arrayref whose elements carry the
entity's own fields, its C<type> flattened to the type name, and the
C<text> it covers.

    for my $e (@{ $td->entity_texts($msg->{content}{text}) }) {
        print "$e->{type}: $e->{text}\n";
    }

The offsets themselves are left exactly as TDLib sent them. They are
sent back unchanged when a message is forwarded, edited or copied, so
rewriting them into character counts would corrupt the message.

=head3 history($chat_id, %opt, $cb)

Pages getChatHistory backwards. Options: C<limit> (messages wanted,
default 50), C<max_pages> (default 10), C<from_message_id>. The
callback receives C<(\@messages, $err, $state)>; C<< $state->{complete} >>
is true when the requested limit was reached or the history was
exhausted.

=head3 edit_message($chat_id, $message_id, $text, %opt, $cb)

Edits a text message. Accepts parse_mode and disable_preview; parse
errors are synchronous, as in send_message.

=head3 edit_message_markup($chat_id, $message_id, $markup, $cb)

Replaces a message's reply markup and nothing else, for updating
buttons after a tap. Pass an empty hashref to remove them.

Note that L</edit_message($chat_id, $message_id, $text, %opt, $cb)>
takes C<reply_markup> as an option, and an edit that omits it drops
whatever buttons the message had.

=head3 answer_poll($chat_id, $message_id, \@option_ids, $cb), stop_poll($chat_id, $message_id, %opt, $cb)

Vote in a poll and close one. Option ids are zero-based positions in
the list the poll was created with, and a single-answer poll takes a
one-element arrayref. stop_poll takes C<reply_markup>.

=head3 message($chat_id, $message_id, $cb), messages($chat_id, \@message_ids, $cb), replied_message($chat_id, $message_id, $cb)

Fetch messages by id. replied_message returns the one a message replies
to, without needing its id.

=head3 message_link($chat_id, $message_id, %opt, $cb), message_link_info($url, $cb), message_count($chat_id, %opt, $cb)

message_link builds a t.me link to a message, with C<media_timestamp>,
C<for_album> and C<in_thread>; message_link_info resolves one back.
message_count counts messages in a chat. C<filter> is required, since
TDLib cannot count unfiltered: give it C<Photo>, C<Video>, C<Document>,
C<Url>, C<Pinned> or any other searchMessagesFilter name, with or
without the prefix. Also takes C<topic> and C<local>, which counts only
what is already cached.

=head3 available_reactions($chat_id, $message_id, %opt, $cb), message_reactions($chat_id, $message_id, %opt, $cb), set_default_reaction($emoji, $cb)

available_reactions lists what may be added to a message;
message_reactions lists what already was, optionally filtered to one
C<emoji>; set_default_reaction picks the one a long press sends. Adding
and removing a reaction is react().

=head3 set_draft($chat_id, $text, %opt, $cb), clear_drafts(%opt, $cb)

Saves an unsent message against a chat, which other clients on the same
account will see. An empty or undefined text clears the draft, which is
how TDLib spells "no draft". Options: C<parse_mode>, C<reply_to>,
C<topic>. clear_drafts empties every chat, keeping secret chats unless
C<exclude_secret> is false.

=head3 send_album($chat_id, \@contents, %opt, $cb)

Sends several media as one group. C<\@contents> are InputMessageContent
hashrefs, such as those L</send_file($chat_id, $path, %opt, $cb)> builds;
C<reply_to>, C<topic>, C<silent> and C<schedule> work as they do there.

=head3 edit_message_caption($chat_id, $message_id, $caption, %opt, $cb), edit_message_media($chat_id, $message_id, \%content, %opt, $cb), edit_message_location($chat_id, $message_id, \%location, %opt, $cb), reschedule($chat_id, $message_id, $when, $cb)

Editing a sent message beyond its text. The caption honours
C<parse_mode> and C<caption_above>; the location takes C<live_period>,
C<heading> and C<proximity_alert_radius>, which it nests in the
liveLocation object TDLib expects. reschedule moves a scheduled message,
and sends it now when C<$when> is omitted.

=head3 resend_messages($chat_id, \@message_ids, $cb), delete_messages_by_sender($chat_id, $user_id, $cb), delete_messages_by_date($chat_id, $min_date, $max_date, %opt, $cb), unpin_all($chat_id, $cb), read_all_mentions($chat_id, $cb)

Bulk operations over a chat's messages. Deleting by date revokes for
everyone unless C<< revoke => 0 >>.

=head3 message_thread($chat_id, $message_id, $cb), thread_history($chat_id, $message_id, %opt, $cb), read_date($chat_id, $message_id, $cb), message_viewers($chat_id, $message_id, $cb), message_properties($chat_id, $message_id, $cb), message_by_date($chat_id, $date, $cb), open_content($chat_id, $message_id, $cb)

Reading around a message: its comment thread and that thread's history,
when it was read and by whom, what may be done with it, the message
nearest a timestamp. open_content marks self-destructing media as
opened, which starts its timer.

=head3 parse_markdown($text, $cb), markdown_text(\%formatted, $cb), text_entities($text, $cb), translate($text, $to_language, %opt, $cb), link_preview($text, $cb), search_hashtags($prefix, %opt, $cb)

Text utilities. parse_markdown turns markdown into a formattedText and
markdown_text turns one back; text_entities finds links, mentions and
the like in plain text without any markup. translate takes a string or
a formattedText and a language code. link_preview asks what Telegram
would show for the links in a text.

=head3 scheduled($chat_id, $cb)

Lists the messages scheduled in a chat but not yet delivered.

=head3 react($chat_id, $message_id, $emoji, %opt, $cb)

Adds an emoji reaction. Options: C<remove> to take the reaction away
again, C<is_big> for the animated form, C<update_recent> (default on)
to fold the emoji into the sender's recent reactions.

=head3 delete_messages($chat_id, \@message_ids, %opt, $cb)

Deletes messages. C<revoke> defaults to true (delete for all
participants).

=head3 forward_messages($chat_id, $from_chat_id, \@message_ids, %opt, $cb)

Forwards messages. Options: C<send_copy>, C<remove_caption>, C<silent>.

=head3 on_message($cb)

Handler for updateNewMessage, called with the decoded message. Its
text is a character string, but any formatting entities on it are
measured in UTF-16 code units: slice them with
L</entity_text($formatted_text, $entity), entity_texts($formatted_text)>
rather than C<substr>.

=head3 send_file($chat_id, $path, %opt, $cb)

Sends a local file. C<kind> selects the content: C<document> (the
default), C<photo>, C<video>, C<audio>, C<animation>, C<voice_note>,
C<video_note>, C<sticker>; an unknown kind croaks.
C<$path> may instead be an InputFile hashref, as returned by
L</upload($path, %opt)>. C<caption> is formatted with the same
C<parse_mode> rules as L</send_message($chat_id, $text, %opt, $cb)>,
and C<reply_to>, C<silent>, C<wait> and C<reply_markup> behave as they
do there.

Each kind nests its InputFile inside a per-kind wrapper object --
inputMessageDocument takes an inputDocument, inputMessagePhoto an
inputPhoto, and so on. This method builds that nesting; handing TDLib
the InputFile directly yields only "InputFile is not specified".

Kinds accept the metadata their wrapper defines, and Telegram
classifies media by what it is given: C<width> and C<height> for
photo, animation, video and sticker; C<duration> for animation, video,
audio, voice_note and video_note; C<title> and C<performer> for audio;
C<length> for video_note; C<emoji> for sticker. C<sticker> and
C<video_note> have no caption field in the schema, so a caption passed
with them is dropped rather than sent.

A Telegram animation is an MP4, not a GIF. Sending a C<.gif> file as
C<animation> succeeds but arrives as a plain document: the conversion
is the sender's job, not the server's. Convert to MP4 first (H.264,
C<yuv420p>) and it arrives as a real animation. Sending an existing
sticker means sending its remote file id, since an arbitrary local
file will not pass Telegram's sticker validation.

=head3 send_poll($chat_id, $question, \@options, %opt, $cb)

Sends a poll, which needs at least two options. Polls are anonymous
unless C<anonymous> is turned off, which is the opposite of TDLib's own
default but matches what Telegram's clients create. Options:
C<multiple> to allow several answers, C<open_period> to close the poll
after that many seconds, C<allow_adding_options>, and C<quiz> with
C<correct> (an option index, default 0) and C<explanation> for a quiz.

All three of these, like the other senders, accept C<reply_to>,
C<silent>, C<reply_markup> and C<wait>.

=head3 send_location($chat_id, $latitude, $longitude, %opt, $cb), send_contact($chat_id, $phone, $first_name, %opt, $cb)

Sends a location or a contact. send_location takes C<accuracy> in
metres; send_contact takes C<last_name>, C<vcard> and C<user_id>.

=head3 search_messages($chat_id, $query, %opt, $cb)

searchChatMessages over one chat. Options: C<limit> (default 50),
C<from_message_id>, C<offset>. The callback receives
C<(\@messages, $err, $info)>, where C<$info> carries C<total_count>
and C<next_from_message_id> for paging.

=head2 Files mixin

=head3 download($file_id, %opt, $cb)

Starts a download (downloadFile). C<on_progress> receives the decoded
file on every related updateFile; the main callback fires with the
file once local.is_downloading_completed is true. A file that is
already downloaded fires it from the downloadFile reply itself: TDLib
emits no updateFile when nothing changed. A download that fails after
starting (TDLib signals this only via updateFile, with
is_downloading_active and is_downloading_completed both false) fails
the callback with a synthetic C<download failed> error. Option:
C<priority> (default 1).

One registration per file id: a second download() for the same id while
the first is in flight fails its callback immediately with a synthetic
C<already in progress> error, delivered synchronously like a parse_mode
error since nothing is sent; the first download is left alone.

=head3 cancel_download($file_id)

Cancels a pending download and fails its callback.

=head3 upload($path, %opt)

Returns an inputFileLocal hashref for use as message content or
elsewhere in a request. It only builds the shape: nothing is sent
and nothing is tracked. The actual upload is reported by TDLib
through the same updateFile as downloads, but on the remote side of
the file (C<remote.uploaded_size> up to
C<remote.is_uploading_completed>), and is observed with
L</on_upload($file_id, $cb)>.

Every send that takes a path uploads asynchronously, so the file must
still be on disk when TDLib gets to it, not merely when the call
returns. A File::Temp object scoped to the enclosing block is the way
this goes wrong: it unlinks on destruction and the upload then fails
with "Need full local (or generate, or inactive remote) location for
upload". Keep the handle alive until the callback runs.

=head3 on_upload($file_id, $cb)

Registers C<$cb> to fire with the decoded file on every updateFile
for C<$file_id>. The registration is removed automatically once the
update with C<remote.is_uploading_completed> true has been
delivered; pass an undef C<$cb> to remove it earlier. The file id
becomes known only after the send is accepted: read it from the
returned message content (for a document,
C<< $msg->{content}{document}{document}{id} >>) and register then.
On close the watchers are dropped silently.

Unlike the other on_* methods, on_upload is a per-id registration,
not a single-handler setter, and it returns nothing.

=head3 file($file_id, $cb), remote_file($remote_id, %opt, $cb), delete_file($file_id, $cb), suggested_file_name($file_id, %opt, $cb)

Local file records. remote_file resolves the persistent id that travels
inside a message; its C<file_type> must match what the file actually is,
and may be given with or without the C<fileType> prefix.

=head3 add_to_downloads($file_id, $chat_id, $message_id, %opt, $cb), remove_from_downloads($file_id, %opt, $cb), pause_download($file_id, $paused, $cb)

The download list Telegram clients show. Options: C<priority>, and
C<delete_cache> to remove the downloaded bytes as well as the entry.

=head3 storage_statistics($cb), optimize_storage(%opt, $cb)

A long-lived client accumulates gigabytes of cached media.
optimize_storage prunes it, bounded by C<size>, C<ttl>, C<count> and
C<immunity_delay>, restricted to or excluding C<chats>. An unset limit
is sent as -1, which TDLib reads as no limit rather than as zero.

=head2 Connection mixin

=head3 connection_state()

Returns the last seen connection state name, or undef before the
first updateConnectionState arrives. One of
connectionStateWaitingForNetwork, connectionStateConnectingToProxy,
connectionStateConnecting, connectionStateUpdating or
connectionStateReady. Anything but the last means you are offline
(or catching up): requests may still be sent, but they will not
reach Telegram until the state returns to connectionStateReady.

=head3 option($name), my_id()

TDLib reports its options as updates rather than replies, so the
module caches them as they arrive; option() reads one back. Boolean
options are cached as 1 or 0 and an empty option as undef.

my_id() is the signed-in account's own user id, which TDLib pushes
right after login. It is undef until then.

=head3 on_connection_state($cb)

Handler for updateConnectionState, called with the state name string
after connection_state() is updated.

=head3 sessions($cb), terminate_session($session_id, $cb), terminate_other_sessions($cb), set_session_ttl($days, $cb)

The devices logged into this account. sessions lists them;
terminate_session logs one out and terminate_other_sessions logs out
everything except this client. set_session_ttl sets how many days of
inactivity ends a session automatically. Session ids are TL C<int64> and
are sent as strings.

=head3 search_chats($query, %opt, $cb), search_public_chats($query, $cb), top_chats($category, %opt, $cb), recommended_chats($cb), recently_opened_chats(%opt, $cb)

Finding chats. search_chats looks through what this account already
knows; search_public_chats reaches Telegram's public directory.
top_chats takes a category: C<users>, C<bots>, C<groups>, C<channels>,
C<inline_bots>, C<calls> or C<forwards>.

=head3 check_chat_username($chat_id, $username, $cb), report_chat($chat_id, %opt, $cb), default_disable_notification($chat_id, $on, $cb)

Whether a public username is free for a chat, reporting a chat with
C<option_id>, C<messages> and C<text>, and whether messages sent to a
chat are silent by default.

=head3 search_by_phone($phone_number, %opt, $cb), my_link($cb), toggle_username($username, $active, $cb)

Finding a user by phone number, this account's own t.me link, and
turning one of your usernames on or off. C<< local => 1 >> restricts the
phone lookup to what is already cached.

=head3 privacy($setting, $cb), set_privacy($setting, \@rules, $cb)

Read and write one privacy setting, named C<status>, C<profile_photo>,
C<phone>, C<bio>, C<birthdate>, C<forwards>, C<invites>, C<calls> or
C<find_by_phone>. Rules are an ordered list of UserPrivacySettingRule
hashrefs and the first match wins, so their order is the policy.

=head2 Bots mixin

=head3 inline_keyboard(\@rows)

Builds a replyMarkupInlineKeyboard for the C<reply_markup> option of
L</send_message($chat_id, $text, %opt, $cb)> and
L</send_file($chat_id, $path, %opt, $cb)>. Each row is an arrayref of
buttons, and each button is C<< { text => ..., data => ... } >> for a
callback button, C<< { text => ..., url => ... } >> for a link, or
C<< { text => ..., web_app => $url } >> to launch a Mini App. A
button with none of the three croaks.

Callback data is TL C<bytes>, which the JSON interface carries base64
encoded; this method encodes it, and L</on_callback_query($cb)>
decodes it again, so callers only ever handle the plain bytes.

=head3 reply_keyboard(\@rows, %opt)

Builds a replyMarkupShowKeyboard, the custom keyboard that replaces a
user's normal one. A button may be a plain string or a hashref;
C<< { text => ..., request => 'phone' } >> (or C<'location'>) asks the
user to share that instead of sending text. Options: C<one_time>,
C<resize> (default on), C<persistent>, C<placeholder>.

Three further button shapes are available.
C<< { text => ..., web_app => $url } >> launches a Mini App, and the
data it sends back arrives through
L</on_web_app_data($cb)>.
C<< { text => ..., request_chat => \%spec } >> and
C<< { text => ..., request_users => \%spec } >> ask the user to pick a
chat or some users. In both, a constraint is applied only for a key you
actually mention, so C<< { bot => 0 } >> means "not a bot" while
leaving it out means "either". request_chat takes C<id>, C<channel>,
C<forum>, C<username>, C<created>, C<bot_is_member>, C<want_title>,
C<want_username>, C<want_photo>, and C<user_rights> / C<bot_rights> as
chatAdministratorRights hashrefs. request_users takes C<id>, C<bot>,
C<premium>, C<max> (default 1), C<want_name>, C<want_username>,
C<want_photo>.

=head3 remove_keyboard(%opt)

Builds a replyMarkupRemoveKeyboard, which takes a custom keyboard away
again. Option: C<personal>.

=head3 set_commands(\@commands, %opt, $cb)

Sets the "/" command menu a bot offers. Each command is
C<< ['start', 'Begin'] >> or
C<< { command => 'start', description => 'Begin' } >>; a leading slash
is stripped. An empty list clears the menu. Options: C<scope> (a
BotCommandScope hashref, default botCommandScopeDefault),
C<language_code>.

=head3 set_bot_name($name, %opt, $cb), set_bot_description($text, %opt, $cb), set_bot_short_description($text, %opt, $cb), set_bot_photo($path, %opt, $cb)

Change a bot's own profile. The description is the long text shown on
an empty chat screen with the bot; the short description is the
one-liner shown in its profile and in search results. set_bot_photo
takes the same C<animation> and C<main_frame_timestamp> options as
L</set_profile_photo($path, %opt, $cb)>.

TDLib addresses a bot by user id. These default to
L</option($name), my_id()>, which is what a bot session wants; pass C<bot_user_id> to
act on a bot from another account that owns it. All four accept
C<language_code> for a localised value.

=head3 on_callback_query($cb)

Handler for updateNewCallbackQuery, called with a hashref carrying
C<id>, C<sender_user_id>, C<chat_id>, C<message_id>, C<type>, and the
decoded C<data>. Answer it with
L</answer_callback_query($id, %opt, $cb)>; Telegram shows the user a
spinner until you do.

=head3 on_inline_query($cb)

Handler for updateNewInlineQuery, the typing-ahead queries an inline
bot answers. It is called with a hashref carrying C<id>,
C<sender_user_id>, C<query>, C<offset> and C<chat_type>. Inline mode
must be turned on for the bot first, through BotFather.

=head3 answer_inline_query($id, \@results, %opt, $cb)

Answers an inline query with a list of article results. Each result is
C<< { title => ..., message => ..., description => ..., url => ...,
thumbnail_url => ..., reply_markup => ... } >>; C<message> is the text
sent when the result is picked, defaulting to the title, and C<id>
is generated if you leave it out. Options: C<cache_time> (default
300), C<personal> for per-user results, C<next_offset> for paging.

=head3 answer_callback_query($id, %opt, $cb)

Answers a callback query. Options: C<text>, C<show_alert>, C<url>,
C<cache_time>. The id is sent as a string, since it is a TL C<int64>
and would lose precision as a number.

=head3 commands(%opt, $cb), delete_commands(%opt, $cb)

Read back or clear the "/" menu set by
L</set_commands(\@commands, %opt, $cb)>. Both take the same C<scope>
and C<language_code> options.

=head3 bot_name(%opt, $cb), bot_description(%opt, $cb), bot_short_description(%opt, $cb)

Read back the values set by the corresponding set_bot_* methods, with
the same C<bot_user_id> and C<language_code> options.

=head3 press($chat_id, $message_id, $data, $cb)

Presses an inline keyboard button on someone else's message, which is
what a user's client does when you tap one. This is the other side of
L</on_callback_query($cb)>: use it to drive a bot rather than to be
one. C<$data> is the plain payload, base64 encoded on the way out for
you. The callback receives a callbackQueryAnswer carrying C<text> and
C<url>.

=head3 inline_query($bot_user_id, $query, %opt, $cb), send_inline_result($chat_id, $query_id, $result_id, %opt, $cb)

The user side of inline mode: ask a bot for results as if you had typed
its username in a message box, then send one of them. inline_query
options are C<chat_id>, C<offset> and C<location>; send_inline_result
takes C<hide_via_bot>. The query id is sent as a string, being a TL
C<int64>.

=head3 start_bot($bot_user_id, $parameter, %opt, $cb)

Sends the C</start> that a deep link produces, passing C<$parameter>
along. Option: C<chat_id>, which defaults to the bot's own chat.

=head3 attachment_menu_bot($bot_user_id, $cb), toggle_attachment_menu($bot_user_id, $on, %opt, $cb)

Read and change whether a bot sits in the attachment menu. This matters
for Mini Apps: L</open_web_app($chat_id, $bot_user_id, $url, %opt, $cb)>
accepts an empty URL only for a bot that is in the menu, and answers
BOT_INVALID otherwise. Option: C<allow_write_access>.

=head3 edit_inline_text($inline_message_id, $text, %opt, $cb), edit_inline_caption($inline_message_id, $caption, %opt, $cb), edit_inline_media($inline_message_id, \%content, %opt, $cb), edit_inline_markup($inline_message_id, \%markup, $cb), edit_inline_location($inline_message_id, \%location, %opt, $cb)

Edit a message a bot sent through inline mode. These address it by the
C<inline_message_id> string that
L</answer_inline_query($id, \@results, %opt, $cb)> results are
identified by, which is a different thing from the
C<(chat_id, message_id)> pair the edit_message_* methods take; the two
are not interchangeable.

edit_inline_text and edit_inline_caption honour C<parse_mode> and hand
a parse failure to the callback rather than to TDLib. All accept
C<reply_markup>. edit_inline_location takes C<live_period>, C<heading>
and C<proximity_alert_radius>, which it nests in the liveLocation
object where TDLib expects them.

=head3 share_chat_with_bot($chat_id, $message_id, $button_id, $shared_chat_id, %opt, $cb), share_users_with_bot($chat_id, $message_id, $button_id, \@user_ids, %opt, $cb)

The user's answer to a C<request_chat> or C<request_users> keyboard
button. The chat and message ids identify the message the button was
on, and C<$button_id> is the C<id> given to that button when the
keyboard was built, which is how a bot tells two pickers apart. Option:
C<check_only>, to test whether the share would be allowed without
performing it.

=head3 allow_bot_messages($bot_user_id, $cb), can_bot_message($bot_user_id, $cb)

Whether a bot you have blocked or never started may message you.
can_bot_message asks; allow_bot_messages grants.

=head3 callback_query_message($chat_id, $message_id, $callback_query_id, $cb)

Fetches the message a callback query came from, for a bot that did not
keep it. The query id is TL C<int64> and is sent as a string.

=head3 check_bot_username($username, $cb), toggle_bot_username($bot_user_id, $username, $active, $cb)

Check whether a username is free for a bot, and turn one of a bot's
usernames on or off. The flag defaults to on.

=head3 create_bot($name, $username, %opt, $cb), owned_bots($cb), bot_token($bot_user_id, %opt, $cb), bot_access_settings($bot_user_id, $cb), set_bot_access_settings($bot_user_id, \%settings, $cb)

Creating and managing bots from an account rather than through
BotFather. create_bot takes C<manager>, the bot that will own the new
one, and C<via_link>. bot_token reads a managed bot's token; C<revoke>
issues a new one and invalidates the old, so anything still using it
stops working.

=head3 set_updates_status($pending_count, %opt, $cb), recent_inline_bots($cb), similar_bots($bot_user_id, $cb), similar_bot_count($bot_user_id, %opt, $cb), open_similar_bot($bot_user_id, $opened_bot_user_id, $cb)

set_updates_status reports a bot's backlog to Telegram, with an optional
C<error>. The rest are discovery: recently used inline bots, and bots
Telegram considers similar to a given one.

=head3 bot_media_previews($bot_user_id, %opt, $cb), add_bot_media_preview($bot_user_id, \%content, %opt, $cb), edit_bot_media_preview($bot_user_id, $file_id, \%content, %opt, $cb), delete_bot_media_previews($bot_user_id, \@file_ids, %opt, $cb), reorder_bot_media_previews($bot_user_id, \@file_ids, %opt, $cb)

The sample media shown on a bot's profile, which are stored per
language. Passing C<language_code> to bot_media_previews asks for one
language's set rather than the list of languages. C<\%content> is an
InputStoryContent hashref, passed through as given.

=head3 set_game_score($chat_id, $message_id, $user_id, $score, %opt, $cb), game_high_scores($chat_id, $message_id, $user_id, $cb), set_inline_game_score($inline_message_id, $user_id, $score, %opt, $cb), inline_game_high_scores($inline_message_id, $user_id, $cb)

Reporting and reading HTML5 game results. C<edit> updates the message to
show the new score and is on by default; C<force> allows a score lower
than the player's best, which is otherwise refused.

=head3 set_menu_button($user_id, %opt, $cb), menu_button($user_id, $cb)

The button beside the message box in a chat with a bot. Options C<text>
and C<url>; a Mini App URL makes it open the app. Passing user id 0 sets
the default for every user.

=head3 add_proxy(\%proxy, %opt, $cb), proxies($cb), enable_proxy($proxy_id, $cb), disable_proxy($cb), remove_proxy($proxy_id, $cb), ping_proxy(\%proxy, $cb)

Proxy configuration. A proxy hashref takes C<server>, C<port> and
C<type> (C<socks5>, C<http> or C<mtproto>), plus C<username> and
C<password> for the first two, C<http_only> for HTTP, and C<secret> for
MTProto. add_proxy enables the proxy unless C<< enable => 0 >>.

=head3 set_network_type($type, $cb), network_statistics(%opt, $cb)

Telling TDLib the network changed (C<none>, C<mobile>, C<roaming>,
C<wifi>, C<other>) lets it reconnect promptly rather than waiting for
its own timers, which matters on a laptop that sleeps or a phone that
changes network.

=head3 log_out($cb), password_state($cb), set_password($old, $new, %opt, $cb), account_ttl($days, $cb), register_device(\%token, %opt, $cb)

Account-level operations. set_password takes C<hint> and
C<recovery_email>. account_ttl reads the inactivity period after which
Telegram deletes the account when called with no C<$days>, and sets it
when given one. register_device takes a DeviceToken hashref for push
notifications, plus C<other_users>.

=head2 WebApps mixin

Mini Apps, which Telegram also calls Web Apps. TDLib does not render
anything: it hands back a URL and a launch id, and hosting the webview
is the application's job. See L</MINI APPS>.

Every method here builds the webAppOpenParameters object itself from
the C<application_name> the client was constructed with, so C<%opt>
carries only C<mode> (C<full_size>, the default, C<compact> or
C<full_screen>), C<theme>, and a per-call C<application_name> override.

=head3 web_app($bot_user_id, $short_name, $cb)

Looks up one Mini App by the short name it was given in BotFather. The
callback receives a foundWebApp carrying the C<web_app> itself, plus
C<request_write_access> and C<skip_confirmation>.

=head3 web_app_link($chat_id, $bot_user_id, $short_name, %opt, $cb), web_app_url($bot_user_id, %opt, $cb), main_web_app($chat_id, $bot_user_id, %opt, $cb)

Three ways to get a launch URL: from a direct link short name, from a
button URL (C<url> option), and from a bot's main Mini App.
web_app_link and main_web_app accept C<start_parameter>; web_app_link
also accepts C<allow_write_access>.

=head3 open_web_app($chat_id, $bot_user_id, $url, %opt, $cb), close_web_app($launch_id, $cb)

Open and close a Mini App session. The callback of open_web_app
receives a webAppInfo carrying C<launch_id> and C<url>; pass that
launch id to close_web_app when the webview goes away. C<$url> should
be the one from a Web App button; an empty string is accepted only for
a bot in the attachment menu, and otherwise answers BOT_INVALID.

=head3 send_web_app_data($bot_user_id, $button_text, $data, $cb)

Sends data back to a bot as if the Mini App had called
C<Telegram.WebApp.sendData()>. The bot sees it through
L</on_web_app_data($cb)>. This is the reply-keyboard flow, so
C<$button_text> must be the text of the Web App button that was
pressed.

=head3 on_web_app_data($cb)

Handler for a messageWebAppDataReceived message. Called as
C<< $cb->($message, $data, $button_text) >> with the payload and button
text lifted out of the content for convenience. L</on_message($cb)>
still sees these messages too.

=head3 answer_web_app_query($query_id, \%result, $cb), web_app_request($bot_user_id, $method, $parameters, $cb), web_app_placeholder($bot_user_id, $cb)

answer_web_app_query is the bot side of C<Telegram.WebApp.switchInlineQuery>:
it answers with one InputInlineQueryResult. web_app_request sends a
custom method call on the Mini App's behalf, with C<$parameters> as a
JSON string. web_app_placeholder fetches the outline shown while an app
loads.

=head2 Forum mixin

Topics in a forum supergroup. A topic id is the id of the message that
opened the topic, so it is an ordinary int53 and not a separate space.

To post into a topic, pass C<topic> to any sending method rather than
calling something different; see
L</send_message($chat_id, $text, %opt, $cb)>.

=head3 create_topic($chat_id, $name, %opt, $cb), edit_topic($chat_id, $topic_id, %opt, $cb), delete_topic($chat_id, $topic_id, $cb)

Create, rename and remove topics. create_topic options: C<color> (an
RGB integer) and C<custom_emoji_id> for the icon, and C<name_implicit>.
edit_topic options: C<name> and C<custom_emoji_id>; the icon is only
touched when C<custom_emoji_id> is given, so renaming leaves it alone.

=head3 topic($chat_id, $topic_id, $cb), topics($chat_id, %opt, $cb), topic_history($chat_id, $topic_id, %opt, $cb), topic_link($chat_id, $topic_id, $cb)

Read topics and their messages. topics options: C<query>, C<limit>
(default 100) and the C<offset_date>, C<offset_message_id>,
C<offset_forum_topic_id> triple for paging. topic_history takes
C<from_message_id>, C<offset> and C<limit>.

=head3 close_topic($chat_id, $topic_id, $closed, $cb), pin_topic($chat_id, $topic_id, $pinned, $cb), unpin_topic_messages($chat_id, $topic_id, $cb), hide_general_topic($chat_id, $hidden, $cb), topic_icons($cb)

State changes. The flag defaults to true, so C<close_topic($chat, $id)>
closes and C<close_topic($chat, $id, 0)> reopens. hide_general_topic
takes no topic id, since the General topic is identified by its absence.
topic_icons lists the icons a client may offer.

=head2 Folders mixin

Chat folders, which Telegram's own clients show as tabs above the chat
list. The folder list itself arrives through updateChatFolders rather
than being fetched.

A folder's name is a chatFolderName wrapping a formattedText, not a
plain string; these methods build that from the C<name> you give, so a
folder spec is an ordinary hashref.

=head3 folder($id, $cb), create_folder(\%spec, $cb), edit_folder($id, \%spec, $cb), delete_folder($id, %opt, $cb), reorder_folders(\@ids, %opt, $cb)

Telegram truncates a folder name to 12 characters and does not say so,
which is worth knowing before a longer name comes back shortened.

A folder spec takes C<name> (required), C<icon> (an icon name such as
C<Work> or C<Party>), C<color_id>, C<shareable>, the chat lists
C<pinned_chat_ids>, C<included_chat_ids> and C<excluded_chat_ids>, and
the flags C<exclude_muted>, C<exclude_read>, C<exclude_archived>,
C<include_contacts>, C<include_non_contacts>, C<include_bots>,
C<include_groups> and C<include_channels>. TDLib replaces the whole
folder on an edit, so any key not passed reverts to its default:
editing only the name empties the membership.

delete_folder takes C<leave_chats>, the chats to leave along with the
folder rather than merely un-filing. reorder_folders takes
C<main_position>, where the unfiled main list sits among the tabs.

=head3 recommended_folders($cb), folder_chat_count(\%spec, $cb), folder_tags($on, $cb)

recommended_folders lists the ready-made folders Telegram suggests.
folder_chat_count reports how many chats a spec would match without
creating it. folder_tags turns the coloured tags on or off.

=head3 folder_invite_link($id, %opt, $cb), folder_invite_links($id, $cb), edit_folder_invite_link($id, $link, %opt, $cb), delete_folder_invite_link($id, $link, $cb), check_folder_invite_link($link, $cb), add_folder_by_link($link, %opt, $cb)

A shareable folder is handed out as a link that adds its chats to
someone else's folder list. Creating and editing take C<name> and
C<chats>, the chats the link includes. TDLib replaces the whole link on
an edit, so leaving C<chats> out empties what the link includes. The
last two take only the link, and C<add_folder_by_link> takes C<chats>
to choose which of the offered chats to actually join.

=head2 Payments mixin

The seller's half of Telegram payments: offering something and answering
the checkout. Actually paying for something is the buyer's half and is
not wrapped; reach it through L</call($function, \%args, $cb)>.

Amounts are integers in the currency's smallest unit, so 500 is five
euros in C<EUR>. The exception is C<XTR>, Telegram Stars, where one unit
is one Star, and where selling digital goods needs no payment provider
at all: leave C<provider_token> unset.

=head3 send_invoice($chat_id, \%invoice, %opt, $cb), invoice_link(\%invoice, %opt, $cb)

Sends an invoice as a message, or builds a shareable link to one. The
invoice hashref takes C<title>, C<description>, C<payload>, C<currency>
and C<prices> (all required), where each price is
C<< [ $label => $amount ] >> or C<< { label => ..., amount => ... } >>.
Optional: C<provider_token> and C<provider_data> for a real payment
provider, C<photo_url> and its dimensions, C<start_parameter>,
C<max_tip> and C<tips>, C<test>, and the C<need_name>, C<need_phone>,
C<need_email>, C<need_shipping> and C<flexible> flags. send_invoice also
takes the usual sending options, C<topic> and C<silent> included.

C<payload> is your own order identifier and comes back at checkout. It
is TL C<bytes>, so it is base64 encoded on the way out for you.

=head3 on_pre_checkout_query($cb), answer_pre_checkout_query($id, %opt, $cb)

The last gate before money moves. Telegram gives a bot only seconds to
answer, and an unanswered query fails the payment, so answer from the
handler. The handler receives C<id>, C<sender_user_id>, C<currency>,
C<total_amount>, C<payload>, C<shipping_option_id> and C<order_info>.
Answering with no C<error> approves; any C<error> string declines and is
shown to the buyer.

=head3 on_shipping_query($cb), answer_shipping_query($id, %opt, $cb)

Only fires for an invoice with C<< need_shipping => 1 >>. The handler
receives C<id>, C<sender_user_id>, C<payload> and C<shipping_address>;
answer with C<options>, an arrayref of
C<< { id => ..., title => ..., prices => [...] } >>, or with an C<error>
to refuse delivery there.

The C<payload> in this handler is a plain string, while the one in
L</on_pre_checkout_query($cb), answer_pre_checkout_query($id, %opt, $cb)>
is TL C<bytes>. Both arrive already in their correct form; the
difference is TDLib's, and is noted here only because it looks like an
inconsistency worth double-checking rather than a bug.

=head3 refund_star_payment($user_id, $charge_id, $cb), star_transactions(%opt, $cb)

Refund a Stars payment by its C<telegram_payment_charge_id>, and read
the Stars ledger. star_transactions options: C<owner> (defaults to this
account), C<direction> (C<incoming> or C<outgoing>), C<subscription_id>,
C<offset>, C<limit>.

=head2 Secret mixin

End-to-end encrypted chats. A secret chat is a separate object from the
chat that displays it: creating one yields a chat whose type is
chatTypeSecret, and the methods below take the B<secret chat id> found
in that type, not the chat id.

Secret chats live only in the local database. They are not on the
server, cannot be read from another device, and do not survive losing
the database.

=head3 new_secret_chat($user_id, $cb), open_secret_chat($secret_chat_id, $cb), secret_chat($secret_chat_id, $cb), close_secret_chat($secret_chat_id, $cb)

Start a secret chat with a user, reopen a known one, read its state, and
close it.

=head3 search_secret_messages($query, %opt, $cb)

Searches the local database, since secret messages exist nowhere else.
Options: C<chat_id> to scope to one chat, C<filter> (a
searchMessagesFilter name, with or without the prefix), C<offset>,
C<limit>.

=head3 set_database_encryption_key($key, $cb), session_accepts_secret_chats($session_id, $on, $cb)

Change the key the local database is encrypted with, and choose whether
a logged-in session may accept secret chats at all. Losing the key loses
every secret chat with it, as nothing on the server can restore them.

=head1 MINI APPS

A Mini App (Telegram also calls it a Web App) is a web page a bot
offers, opened inside a Telegram client. TDLib does not render it. It
resolves the app, returns a URL and a launch id, and relays the data
the page sends back; hosting a webview and loading the URL is the
application's job. Nothing here needs a browser if all you want is the
data channel.

The usual flow is:

    $td->web_app($bot_id, 'probe', sub {
        my ($found, $err) = @_;
        ...
    });
    $td->open_web_app($chat_id, $bot_id, $button_url, sub {
        my ($info, $err) = @_;
        # hand $info->{url} to a webview, keep $info->{launch_id}
    });
    $td->close_web_app($launch_id, sub { });

Data flows back either through
L</send_web_app_data($bot_user_id, $button_text, $data, $cb)>, which a
client calls on the page's behalf and the bot receives through
L</on_web_app_data($cb)>, or through
L</answer_web_app_query($query_id, \%result, $cb)> for the inline
variant.

=head2 The platform identifier

C<application_name> is not a free-form label. It is sent to Telegram as
the platform string and handed to the page as C<tgWebAppPlatform>.
Telegram accepts 0-64 characters from C<A-Za-z0-9_> and rejects
anything else with C<PLATFORM_INVALID>, an error that names nothing
near the real cause; a hyphen is the easy way to trip it. This module
validates the value when the client is constructed, so the failure
arrives with an explanation instead.

Any accepted value works, but the value still matters. Real clients
send a conventional identifier (C<android>, C<ios>, C<macos>,
C<tdesktop>, C<weba>, C<webk>) and Mini App pages branch on it to pick
layout, theming and available features. An invented name passes
validation and then lands in whatever an app does with an unrecognised
platform. The default is C<tdesktop>.

=head2 Launch URLs carry credentials

The URL returned by open_web_app and the web_app_*_url methods has the
signed init data in its fragment: the user's name, username, photo URL
and an authentication hash. It is a credential. Do not log it, paste it
into a bug report, or store it anywhere the page itself would not go.

=head1 AUTHORIZATION

TDLib drives authorization as a state machine reported through
updateAuthorizationState; L</auth_state()> exposes the current state.
With auto_auth on (the default), each state is answered automatically
or routed to a credential callback:

=over 4

=item authorizationStateWaitTdlibParameters

setTdlibParameters is sent automatically from the constructor options.
No callback. An error reply (bad api credentials, an unwritable
database_directory) fails login: the values come from the constructor,
so there is no interactive channel to retry through.

=item authorizationStateWaitPhoneNumber

bot_token is sent when given; otherwise requestQrCodeAuthentication
when on_qr is set and no phone_number was given; otherwise the
phone_number is sent. No callback in any branch. An error reply
(an invalid phone number or bot token) fails login, for the same
reason as above.

=item authorizationStateWaitCode

C<on_code> receives C<($info, $submit)>: $info is the decoded
authenticationCodeInfo, $submit is a code ref that sends the code.
The split exists so the code can come from anywhere (a prompt, a GUI,
a queue) without blocking the loop. A missing callback fails login.

A rejected submission does not fail login: TDLib stays in the state
after an error reply (a mistyped code, an expired one), so the
handler is called again as C<($info, $submit, $err)> with the decoded
error as the third argument, and may submit a corrected value. To
give up instead, close the client.

=item authorizationStateWaitPassword

C<on_password> receives C<($info, $submit)>; $info carries the
password_hint. A missing callback fails login. A rejected password
re-asks with the error as a third argument, as above.

=item authorizationStateWaitEmailAddress, authorizationStateWaitEmailCode

C<on_email> and C<on_email_code>, same C<($info, $submit)> shape and
the same retry-on-error behaviour.

=item authorizationStateWaitOtherDeviceConfirmation

C<on_qr> receives C<($link)> only. The signature is deliberately
asymmetric: QR confirmation has nothing to submit, the other device
confirms the login, so there is no $submit callback.

=item authorizationStateWaitRegistration

Answered automatically from the register option; without it login
fails. An error reply from registerUser fails login: like the other
automatic steps, it has no interactive channel.

=item authorizationStateWaitPremiumPurchase

Cannot be satisfied programmatically; login fails with an error.

=item authorizationStateReady

The login() callback succeeds.

=item authorizationStateClosed

Pending requests, in-flight sends and downloads are failed, close()
callbacks run, then on_close fires.

=back

A login failure that arrives when no login() is pending is reported
to the on_error handler instead (or warn, when none is set), and
recorded: a login() called after the failure fails deferred with the
same error rather than waiting for a state that never comes.

=head1 UPDATES

Anything arriving without a pending C<@extra> is an update -- with one
exception: a reply whose C<@extra> matches no pending and no recently
timed-out request is a stray, dropped with a warning rather than
dispatched as an update. Dispatch
order: the authorization state machine, then the per-type handlers
that maintain the user and chat caches, track the connection state
and drive downloads, upload watchers and in-flight sends, then the
generic on_update handler.

A live client emits updateOption traffic (and other service updates)
that reaches on_update as soon as a loop runs, before any request is
made. Handlers must tolerate updates they do not recognize.

The chat cache is maintained against a fixed table of chat-field
updates (updateChatTitle, updateChatLastMessage, updateChatPosition
and friends) that targets the pinned TDLib 1.8.66, commit
022d60202e446ad1287b9fb68e687c8a0760788b. A newer TDLib that renames
these updates would leave the cache stale; the unknown updates would
fall through to on_update only.

Payload fields the schema marks nullable (last_message, draft_message,
photo, action_bar, theme, block_list, pending_join_requests) are
assigned even when the update omits them: TDLib drops null object
fields from its JSON entirely, so an absent key means the value was
cleared, not that it stayed unchanged.

=head1 ESCAPE HATCH

The convenience methods cover a small fraction of the API. send() and
execute() take any raw TDLib request hashref, so the roughly one
thousand unwrapped TDLib methods remain fully usable:

    $td->send({ '@type' => 'getCountries' }, sub {
        my ($res, $err) = @_;
        ...
    });

Do not set C<@extra> yourself; see L</send(\%request, $cb, %opt)>.

For offline tests, _inject_raw($json) feeds a JSON string through the
normal dispatch path. It is an internal test hook, not part of the
supported API.

Injecting an authorizationStateClosed makes the module forget the
client. That is only safe while nothing has been sent to it: tdjson
creates a client on its first request, so an id that never carried one
has nothing behind it. Inject it after real traffic and the module
stops tracking a client TDLib still holds.

=head1 UNICODE

Work in character strings. Text you pass in is encoded for you, and
text you get back is decoded for you; the conversion happens at the XS
boundary, where TDLib's JSON is read and written as UTF-8 octets.

    $td->send_message($chat_id, "\x{41F}\x{440}\x{438}\x{432}\x{435}\x{442}", sub { });

    $td->on_message(sub {
        my ($msg) = @_;
        my $text = $msg->{content}{text}{text};
        # a character string: length is in characters, not bytes
        printf "%d characters\n", length $text;
    });

Do not encode it yourself. Passing bytes you have already run through
C<Encode::encode> sends those bytes as though each one were a
character, and Telegram stores the result:

    use Encode ();
    my $text = "\x{410}\x{411}";               # two characters

    $td->send_message($chat_id, $text, sub { });
    # on the wire: d0 90 d0 91   -- correct

    $td->send_message($chat_id, Encode::encode('UTF-8', $text), sub { });
    # on the wire: c3 90 c2 90 c3 90 c2 91   -- mojibake, and no error

Nothing warns about this. Both calls succeed, and the damage is only
visible in the message itself, so it is worth being deliberate about
where text enters your program: decode once at the edge, and pass
characters from there on.

Formatting entities are counted differently again: TDLib gives
C<offset> and C<length> in UTF-16 code units, not characters. Use
L</entity_text($formatted_text, $entity), entity_texts($formatted_text)>
rather than C<substr>, which is right only while the text stays inside
the BMP.

The same applies to every string the module sends -- captions, chat
titles, bot descriptions, poll questions and options, keyboard labels,
inline query results, search queries -- and to the C<@extra>
correlation ids, which are generated internally and never contain
anything but digits.

Printing text you received to a filehandle with no encoding layer
raises "Wide character in print". Set the layer once:

    binmode STDOUT, ':encoding(UTF-8)';

Reading a code or password from STDIN in an interactive login is the
mirror image: C<binmode STDIN, ':encoding(UTF-8)'> if it may contain
anything but ASCII, so that what you submit is characters.

=head1 ERROR HANDLING

A TDLib error is never thrown: invalid arguments croak at the call
site, but anything the server rejects arrives through the callback.
Every asynchronous callback follows the
contract C<< $cb->($result, $err) >>: C<$err> is undef on success and
a hashref on failure, and C<$result> is undef whenever C<$err> is
set. Test C<$err>, not C<$result>.

L</history($chat_id, %opt, $cb)> is the one exception, and it is
deliberate: paging can fail partway, so a failure after some pages
have arrived hands you both the messages collected so far and the
error that stopped it.

A TDLib error arrives as the decoded object:

    { '@type' => 'error', code => 400, message => 'PHONE_NUMBER_INVALID' }

Synthetic errors generated by the module itself use the same shape
with code -1:

=over 4

=item *

C<timeout> -- a L<send()|/"send(\%request, $cb, %opt)"> request whose
C<timeout> option expired. The late reply, if it ever arrives, is
dropped with a warning; it is never delivered to a reused C<@extra>.

=item *

C<client closed> -- delivered to every in-flight request, pending
send and active download when the client closes; a pending login()
fails with C<client closed during login>.

=item *

C<client is closed> -- a L<send()|/"send(\%request, $cb, %opt)">
attempted after the client closed; nothing is sent and the callback
fails deferred.

=item *

C<download canceled> -- delivered by L</cancel_download($file_id)>.

=item *

C<download failed> -- a L</download($file_id, %opt, $cb)> that failed
after starting; TDLib reports a permanent download failure only
through updateFile, never as a request reply.

=back

=head2 Rate limiting: error code 429

Telegram answers too-frequent requests with error code 429 and a
message of the form C<Too Many Requests: retry after N>, where N is
the number of seconds to wait. In this TDLib the generic error type
carries only C<code> and C<message>, so the delay exists only in the
message text and must be parsed from it. Do not retry immediately,
and never retry in a tight loop: that is the pattern that gets an
account limited. Back off for at least the stated delay, with a
timer rather than a blocking sleep. TDLib performs its own internal
rate limiting for many operations -- it queues and paces requests on
its own -- so a 429 that reaches you is a hard signal, not routine
operation.

The module deliberately implements no automatic retry: a wrong retry
policy inside a binding hides the signal and can make limiting
worse. The back-off policy belongs to the caller; see
L<EV::Telegram::TDLib::Cookbook/"Handling rate limits">.

One structured exception: a failed message send surfaces through
updateMessageSendFailed, whose message carries a
messageSendingStateFailed with a numeric C<retry_after> field in
seconds, next to C<can_retry>. The L</send_message($chat_id, $text, %opt, $cb)>
callback receives only the error object; watch updateMessageSendFailed
via L</on_update($cb), on_error($cb)> when you need the structured
field.

=head2 Internal failures

Internal failures that own no request -- a TDLib frame that fails JSON
decoding, a user callback that dies -- are reported to the C<on_error>
handler, or to warn when none is set. A dying callback is contained by
the dispatch (wrapped in G_EVAL): it is reported, and the remaining
updates in the same batch still run; the drain does not abort. The
close chain is contained per callback as well: one dying callback
during close cannot skip the remaining pending failures, the close()
callbacks or on_close.

The containment covers dispatch context. An exception in a
L<send()|/"send(\%request, $cb, %opt)"> timeout callback runs in an EV
timer, not in the dispatch: it is not contained and propagates out of
EV::run like any other EV watcher callback.

Some errors are delivered synchronously, before the method returns:
a parse_mode failure in
L</send_message($chat_id, $text, %opt, $cb)> or
L</edit_message($chat_id, $message_id, $text, %opt, $cb)>, and equally
in send_file, send_poll and answer_inline_query, invokes the callback
with the parseTextEntities error before the method returns, and
nothing is sent. A download already in progress and a mark_read with
nothing to mark report the same way.

=head1 ENVIRONMENT

=over 4

=item EV_TDLIB_SHUTDOWN_TIMEOUT

Seconds the END block waits for open clients to finish closing before
giving up, default 3. Giving up tears TDLib's statics down while it is
still closing, which can abort the process at exit -- TDLib detaches
its scheduler thread rather than joining it once exit has begun, so
the crash is a race and will not show on every run. Raise this on a
heavily loaded machine or under a sanitizer, where everything runs
several times slower.

=item TDLIB_LOG_VERBOSITY

TDLib's log verbosity level, applied once when the module is loaded.
Defaults to 1; TDLib's own default of 5 is very noisy on stderr.

=item TD_API_ID, TD_API_HASH, TD_PHONE, TD_BOT_TOKEN, TD_DATABASE_DIRECTORY

Not the module's API: the credential convention shared by the scripts
in F<eg/> and by F<xt/live_auth.t>. The module itself takes
credentials only as constructor options; see L</new(%opt)>.

=back

=head1 EXAMPLES

Runnable scripts live in F<eg/> (from the distribution root:
C<perl -Mblib eg/NAME.pl>; credentials come from the environment, see
L</ENVIRONMENT>):

=over 4

=item F<eg/01-login.pl>

user login with phone, SMS code and 2FA; creates the session database

=item F<eg/02-bot-echo.pl>

bot login via token; echoes incoming text messages

=item F<eg/03-list-chats.pl>

loads the chat list and prints id and title per chat

=item F<eg/04-send-message.pl>

sends a markdown message and waits for real delivery

=item F<eg/05-download-file.pl>

downloads a file id with progress percentage

=item F<eg/06-raw-method.pl>

raw send()/execute() for methods the mixins do not wrap

=item F<eg/07-gtk4-chat.pl>

a two-pane GTK4 chat window driven by EV rather than by gtk_main

=item F<eg/08-tickit-chat.pl>

the same two panes in a terminal, on the same single loop

=item F<eg/09-mcp-server.pl>

exposes Telegram as MCP tools over JSON-RPC on stdio

=item F<eg/10-webapp-bot.pl>

offers a Mini App button and prints the data the page sends back

=back

L<EV::Telegram::TDLib::Cookbook> has task-oriented recipes.

=head1 CAVEATS

=over 4

=item *

Not fork-safe. TDLib itself is not fork-safe, so every method croaks
after fork. Do not fork with an open client. Forking before this
process has ever made one is allowed, and is how a preforking worker
pool should be built: the child inherits a pump that was never used.

=item *

One reader thread per process, shared by all clients. It starts with
the first client and runs until the process ends: closing every
client releases the loop reference, so EV::run can return, but the
reader itself is only joined by the END-block shutdown.

=item *

The default EV loop only. Requests are delivered on EV_DEFAULT; a
non-default loop cannot receive them. Destroying the default loop
(L<EV/default_destroy>) while a client is open is out of contract: the
reader thread would keep signalling the freed loop through
ev_async_send. Close every client first.

=item *

Not safe with Perl ithreads. The pump initialises once per process, so
on a threaded perl any C<< threads->create >> after this module is
loaded dies with "the pump cannot serve a second interpreter" -- even
for a thread that never touches Telegram. Fork instead, subject to the
fork rules above.

Pinned assumption: TDLib's receive/execute buffer is thread-local. The
no-lock design -- the reader thread copies every td_receive result
before anything else runs, and execute() needs no lock against it --
rests on the C<current_output> buffer in TDLib's ClientJson.cpp being
C<TD_THREAD_LOCAL>. That is an implementation detail, not a public
guarantee: the header only promises the pointer stays valid until the
next call. Verified against the bundled TDLib 1.8.66, commit
022d60202e446ad1287b9fb68e687c8a0760788b; re-verify whenever the pin
moves, because a process-global buffer would make concurrent execute()
a use-after-free race.

=item *

Clients stay registered until closed. The registry holds a strong
reference on purpose: TDLib requires every client to be closed before
process exit, so an object must not vanish when the caller drops its
last reference. L</close($cb)> is not optional; dropping your last
Perl reference does not close anything. See L</AUTHORIZATION> for the
Closed state that ends the lifecycle.

=item *

An END block closes leftover clients and pumps the loop for a bounded
interval (three seconds) so TDLib flushes its database, then joins the
reader thread. It is a safety net, not a substitute for close().

=item *

A callback that dies is contained and reported through on_error; the
drain continues. See L</ERROR HANDLING>.

=back

=head1 SECURITY

The database directory holds the session: whoever reads it owns the
account. Treat it as exactly as sensitive as a password: restrictive
permissions, no commits, no backups to third-party storage.

Set database_encryption_key so the local database is encrypted at
rest, and keep the key out of source control.

api_id and api_hash identify your application to Telegram. Read them
from the environment (TD_API_ID, TD_API_HASH), never hardcode them.

=head1 REQUIREMENTS

=over 4

=item *

perl 5.12 or later, built with 64-bit integers. The Makefile refuses
to build when ivsize is below 8: Telegram chat and user ids are
int64, and message ids are shifted left by 20 bits, so they must
never round-trip through an NV.

=item *

L<EV> 4.11 or later.

=item *

L<Cpanel::JSON::XS> 4.00 or later.

=item *

L<Alien::TDLib>, at configure and build time. It provides TDLib
1.8.66, pinned at commit 022d60202e446ad1287b9fb68e687c8a0760788b;
TDLib itself is licensed under the Boost Software License 1.0.

=back

=head1 LIMITATIONS

Deliberately out of scope:

=over 4

=item *

No Bot API (HTTP) client; this binding speaks tdjson only.

=item *

No voice or video calls.

=item *

No secret-chat sugar beyond the use_secret_chats switch.

=item *

Around 160 of TDLib's roughly one thousand methods have a
hand-written wrapper. For the rest,
L<call()|/"call($function, \%args, $cb)"> validates argument names
against a shipped schema catalogue, and
L<send()|/"send(\%request, $cb, %opt)"> and L</execute(\%request)>
are the escape hatch (see L</ESCAPE HATCH>).

=item *

No log message callback (TDLib's setLogMessageCallback is not bound);
TDLIB_LOG_VERBOSITY (see L</ENVIRONMENT>) is the only log control.

=item *

Linux-focused: developed and CI-tested on Linux, untested elsewhere.

=item *

The default EV loop only; see L</CAVEATS>.

=back

=head1 SEE ALSO

L<Alien::TDLib>, L<EV>, L<EV::Telegram::TDLib::Cookbook>,
L<https://core.telegram.org/tdlib> and the td_api documentation
linked from it, L<Telegram::JsonAPI> (synchronous prior art on CPAN).

=head1 AUTHOR

vividsnow

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
