use strict;
use warnings;
use Config;
use Test::More;
use EV;
use EV::Telegram::TDLib;

my $id = EV::Telegram::TDLib::_create_client_id();
ok $id > 0, 'client created in the parent';

SKIP: {
    skip 'no fork on this platform', 2 unless $Config::Config{d_fork};
    my $pid = fork;
    defined $pid or die "fork: $!";
    if (!$pid) {
        my $ok = eval { EV::Telegram::TDLib::_create_client_id(); 1 };
        exit($ok ? 1 : ($@ =~ /after fork/ ? 0 : 2));
    }
    waitpid $pid, 0;
    is $? >> 8, 0, 'the child croaks with an after-fork message';
    ok 1, 'the parent survived the child';
}

# deliberately no close first: shutting down WITH a live client is the
# case being measured here
my $t0 = time;
EV::Telegram::TDLib::_shutdown();
cmp_ok time - $t0, '<', 5,
    'shutdown does not wait out the full receive timeout';

done_testing;
