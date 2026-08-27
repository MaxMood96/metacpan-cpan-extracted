use strict;
use warnings;
use Test::More;

# This file stubs _send, so the END-block shutdown cannot deliver its close
# requests and would idle out the whole budget at exit. Nothing was ever sent
# to TDLib here, so there is nothing to wait for.
BEGIN { $ENV{EV_TDLIB_SHUTDOWN_TIMEOUT} = 0.1 }

use EV;
use EV::Telegram::TDLib;

my @sent;
{
    no warnings 'redefine';
        *EV::Telegram::TDLib::_send = sub { push @sent, $_[1]; };
}

my ($code_cb, $password_cb);
my $td = EV::Telegram::TDLib->new(
    api_id       => 12345,
    api_hash     => 'deadbeef',
    phone_number => '+10000000000',
    database_directory => 't/tmp-auth',
    on_code     => sub { my ($info, $submit) = @_; $code_cb = $submit },
    on_password => sub { my ($info, $submit) = @_; $password_cb = $submit },
);

my $ready;
$td->login(sub { $ready = [@_] });

$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitTdlibParameters"}}));
like $sent[-1], qr/setTdlibParameters/, 'parameters sent automatically';
like $sent[-1], qr/"api_id":12345/, 'api_id is a number, not a string';
unlike $sent[-1], qr/"parameters"\s*:/, 'uses the flat 1.8.x parameter shape';

$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPhoneNumber"}}));
like $sent[-1], qr/setAuthenticationPhoneNumber/, 'phone number sent';

$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitCode","code_info":{"@type":"authenticationCodeInfo"}}}));
ok $code_cb, 'on_code was invoked with a submit callback';
$code_cb->('54321');
like $sent[-1], qr/checkAuthenticationCode/, 'the submitted code was sent';

$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPassword","password_hint":"hint"}}));
ok $password_cb, 'on_password was invoked';
$password_cb->('hunter2');
like $sent[-1], qr/checkAuthenticationPassword/, 'the password was sent';

$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}));
ok $ready, 'login completed';
is $ready->[1], undef, 'login reported no error';

is $td->auth_state, 'authorizationStateReady', 'state is exposed';

{
    my $td2 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x', auto_auth => 0,
        database_directory => 't/tmp-auth-late',
    );
    $td2->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}));
    my $late;
    $td2->login(sub { $late = [@_] });
    ok !$late, 'late login does not fire synchronously';
    EV::run(EV::RUN_NOWAIT);
    ok $late, 'late login fires after Ready';
    is $late->[1], undef, 'late login reports no error';
}

{
    my $td3 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x', auto_auth => 0,
        database_directory => 't/tmp-auth-closed',
    );
    $td3->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateClosed"}}));
    my $late3;
    $td3->login(sub { $late3 = [@_] });
    ok !$late3, 'closed login does not fire synchronously';
    EV::run(EV::RUN_NOWAIT);
    ok $late3, 'closed login fires';
    is $late3->[0], undef, 'closed login has no result';
    ok $late3->[1]{message}, 'closed login reports an error';
}

# --- a second login() before Ready chains instead of replacing
{
    my $td4 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x', auto_auth => 0,
        database_directory => 't/tmp-auth-chain',
    );
    my (@r1, @r2);
    $td4->login(sub { @r1 = @_ });
    $td4->login(sub { @r2 = @_ });
    $td4->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}));
    ok @r1, 'the first login callback is not dropped by the second';
    ok @r2, 'the second login callback fired';
    is $r1[1], undef, 'the first login reports no error';
    is $r2[1], undef, 'the second login reports no error';
}

# --- a failed login fails every chained callback
{
    my $td5 = EV::Telegram::TDLib->new(
        api_id       => 1,
        api_hash     => 'x',
        phone_number => '+10000000000',
        database_directory => 't/tmp-auth-chainfail',
    );
    my (@e1, @e2);
    $td5->login(sub { @e1 = @_ });
    $td5->login(sub { @e2 = @_ });
    $td5->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitCode","code_info":{"@type":"authenticationCodeInfo"}}}));
    ok @e1, 'the first login callback got the failure';
    ok @e2, 'the second login callback got the failure';
    like $e1[1]{message}, qr/no on_code callback/, 'the failure reaches the first';
    like $e2[1]{message}, qr/no on_code callback/, 'the failure reaches the second';
}

# --- two late login() calls after Ready both fire
{
    my $td6 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x', auto_auth => 0,
        database_directory => 't/tmp-auth-late2',
    );
    $td6->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}));
    my (@l1, @l2);
    $td6->login(sub { @l1 = @_ });
    $td6->login(sub { @l2 = @_ });
    ok !@l1 && !@l2, 'neither late login fires synchronously';
    EV::run(EV::RUN_NOWAIT);
    ok @l1, 'the first late login fired';
    ok @l2, 'the second late login fired';
    is $l1[1], undef, 'the first late login reports no error';
    is $l2[1], undef, 'the second late login reports no error';
}

# --- two late login() calls after Closed both fire with the error
{
    my $td7 = EV::Telegram::TDLib->new(
        api_id => 1, api_hash => 'x', auto_auth => 0,
        database_directory => 't/tmp-auth-late3',
    );
    $td7->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateClosed"}}));
    my (@l1, @l2);
    $td7->login(sub { @l1 = @_ });
    $td7->login(sub { @l2 = @_ });
    EV::run(EV::RUN_NOWAIT);
    ok @l1 && @l2, 'both late logins after Closed fired';
    ok $l1[1]{message} && $l2[1]{message}, 'both report the closed error';
}

done_testing;
