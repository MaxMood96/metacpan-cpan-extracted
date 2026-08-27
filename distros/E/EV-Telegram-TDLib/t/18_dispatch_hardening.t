use strict;
use warnings;
use Test::More;
use EV;
use EV::Telegram::TDLib;

# _set_dispatch swaps before dropping the old ref: a DESTROY that
# re-enters from the dec must see the new value, not a dangling pointer
my $reentered = 0;
{
    package TDReenter;
    sub DESTROY {
        $reentered++;
        EV::Telegram::TDLib::_set_dispatch(sub { });
    }
}
# the coderef must close over something: a capture-less anon sub is a pad
# constant and its DESTROY would only fire at global destruction
my $keep = 1;
my $cb = bless(sub { $keep }, 'TDReenter');
EV::Telegram::TDLib::_set_dispatch($cb);
undef $cb;
EV::Telegram::TDLib::_set_dispatch(sub { });
is $reentered, 1, 'DESTROY re-entered _set_dispatch during the swap';

# a dying dispatch plus a dying __WARN__ hook must not unwind the drain
# and leak the rest of the queue
my $calls = 0;
my $hook_calls = 0;
EV::Telegram::TDLib::_set_dispatch(sub { $calls++; die "dispatch boom\n" });

my $id = EV::Telegram::TDLib::_create_client_id();
ok $id > 0, 'client created';
EV::Telegram::TDLib::_send($id, '{"@type":"getOption","name":"version"}');
EV::Telegram::TDLib::_send($id, '{"@type":"getOption","name":"version"}');

{
    local $SIG{__WARN__} = sub { $hook_calls++; die "warn hook boom\n" };
    my $poll = EV::timer 0.05, 0.05, sub { EV::break if $calls >= 2 };
    my $watchdog = EV::timer 10, 0, sub { EV::break };
    EV::run;
}

cmp_ok $calls, '>=', 2,
    'every queued message was dispatched despite dying dispatch and __WARN__';
cmp_ok $hook_calls, '>=', 2,
    'each dispatch failure still reached the warn hook';

EV::Telegram::TDLib::_set_dispatch(\&EV::Telegram::TDLib::_dispatch_raw);

# --- _drain_error routes a dispatch death to the client's on_error
my @derr;
my $td = EV::Telegram::TDLib->new(
    api_id => 1, api_hash => 'x', auto_auth => 0,
    database_directory => 't/tmp-drain',
    on_error => sub { push @derr, $_[0] },
);
EV::Telegram::TDLib::_drain_error($td->{client_id}, 'dispatch died: boom');
is scalar @derr, 1, 'a dispatch death reaches on_error';
like $derr[0], qr/dispatch died: boom/, 'on_error carries the drain message';

# an unknown client id falls back to warn
my @dwarn;
{
    local $SIG{__WARN__} = sub { push @dwarn, $_[0] };
    EV::Telegram::TDLib::_drain_error(999999, 'dispatch died: stray');
}
is scalar @dwarn, 1, 'a clientless dispatch death warns';
like $dwarn[0], qr/dispatch died: stray/, 'the fallback warning carries the message';

# a dying on_error must not propagate out of the helper
$td->on_error(sub { die "on_error boom\n" });
my @dwarn2;
my $lived = do {
    local $SIG{__WARN__} = sub { push @dwarn2, $_[0] };
    eval { EV::Telegram::TDLib::_drain_error($td->{client_id}, 'dispatch died: again'); 1 };
};
ok $lived, 'a dying on_error does not unwind the drain helper';
is scalar @dwarn2, 1, 'a dying on_error falls back to warn';
like $dwarn2[0], qr/dispatch died: again/, 'the fallback warning carries the message';

# a raw client id is not in %CLIENTS, so the END-block shutdown never closes
# it; leaving TDLib a live client at exit aborts while its statics tear down
{
    my $shut_done = 0;
    EV::Telegram::TDLib::_set_dispatch(sub {
        my (undef, $json) = @_;
        $shut_done = 1 if $json =~ /authorizationStateClosed/;
        EV::break if $shut_done;
    });
    EV::Telegram::TDLib::_send($id, '{"@type":"close"}');
    # bound on the flag, not the clock: RUN_ONCE with no events left blocks
    my $shut_late = 0;
    my $shut_w = EV::timer 15, 0, sub { $shut_late = 1; EV::break };
    EV::run(EV::RUN_ONCE) while !$shut_done && !$shut_late;
    $shut_w->stop;
    EV::Telegram::TDLib::_set_dispatch(\&EV::Telegram::TDLib::_dispatch_raw);
    ok $shut_done, 'the raw client closed before exit';
}

# TDLib always sends an object, but the decoder allows nonref, so a bare
# scalar or an array must be reported rather than treated as a hash
{
    my @shape;
    my $td2 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x',
        database_directory => 't/tmp-dispatch-shape',
        on_error => sub { push @shape, $_[0] },
    );
    for my $payload ('[]', '"a string"', '42') {
        my $lived = eval { $td2->_inject_raw($payload); 1 };
        ok $lived, "a non-object payload ($payload) does not die";
    }
    is scalar @shape, 3, 'each non-object payload was reported';
    like $shape[0], qr/not an object/, 'the error says what was wrong';
}

# updates that arrive without the id their handler keys on must be ignored,
# not filed under the empty string where a later lookup could collide
{
    my @noise;
    local $SIG{__WARN__} = sub { push @noise, $_[0] };
    my $td3 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x',
        database_directory => 't/tmp-dispatch-ids',
        on_error => sub { },
    );
    my @idless = (
        '{"@type":"updateFile","file":{}}',
        '{"@type":"updateMessageSendSucceeded"}',
        '{"@type":"updateMessageSendFailed"}',
        '{"@type":"updateChatTitle"}',
        '{"@type":"updateChatPosition"}',
    );
    $td3->_inject_raw($_) for @idless;
    diag "  unexpected warning: $_" for @noise;
    is scalar @noise, 0, 'an id-less update warns nothing from inside the module';
    is scalar keys %{ $td3->{cache}{sending} || {} }, 0,
        'no empty-string key was created in the sending table';
}

done_testing;
