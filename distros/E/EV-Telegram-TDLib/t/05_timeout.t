use strict;
use warnings;
use Test::More;

# This file stubs _send, so the END-block shutdown cannot deliver its close
# requests and would idle out the whole budget at exit. Nothing was ever sent
# to TDLib here, so there is nothing to wait for.
BEGIN { $ENV{EV_TDLIB_SHUTDOWN_TIMEOUT} = 0.1 }

use EV;
use EV::Telegram::TDLib;

# a real getMe is answered by TDLib with an error within milliseconds
# (no parameters set), which would beat the 0.2s timeout to the callback
{
    no warnings 'redefine';
    *EV::Telegram::TDLib::_send = sub { };
}

my $td = EV::Telegram::TDLib->new(
    api_id => 1, api_hash => 'x', auto_auth => 0,
    database_directory => 't/tmp-timeout',
);

my @got;
my $extra = $td->send({ '@type' => 'getMe' }, sub { push @got, [@_] }, timeout => 0.2);

my $watchdog = EV::timer 5, 0, sub { fail('watchdog'); EV::break };
my $stop = EV::timer 0.5, 0, sub { EV::break };
EV::run;

is scalar @got, 1, 'the callback fired once';
is $got[0][0], undef, 'no result';
is $got[0][1]{message}, 'timeout', 'timeout error delivered';
is $got[0][1]{code}, -1, 'timeout uses code -1';
ok !exists $td->{pending}{$extra}, 'no longer pending';

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, $_[0] };
$td->_inject_raw(qq({"\@type":"user","id":1,"\@extra":"$extra"}));
is scalar @got, 1, 'the late reply did not reach the callback again';
like $warnings[0], qr/late reply/, 'the late reply warned';

# --- a timeout scheduled after blocking outside the loop must be
# measured from now, not from the stale ev_now: without now_update it
# fires immediately, a spurious timeout TDLib might have answered
EV::now_update();
my $t0 = EV::now;
select(undef, undef, undef, 1.0);
my (@got2, $fired_at);
$td->send({ '@type' => 'getMe' }, sub {
    @got2 = @_;
    $fired_at = EV::now;
    EV::break;
}, timeout => 0.4);
EV::run;
is $got2[1]{message}, 'timeout', 'the timeout still fires';
cmp_ok $fired_at - $t0, '>', 1.2, 'the full timeout elapsed despite the stale ev_now';

done_testing;
