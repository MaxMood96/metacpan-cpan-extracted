#!perl
# The byte budget on a retention pass: after the time sweep, a store still
# over `bytes` loses its oldest segments - sidecars in pairs - until it
# fits. The window says how far back must stay visible; the budget says what
# that may cost; the budget wins, because a full disk loses everything.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;
use Punk::Observe::Retain ();
use Punk::Plugin::Observe ();

my $S  = 'Punk::Observe::Store';
my $T0 = '1774224000000000000';

sub logline {
    my ($i, $body) = @_;
    my $t = $T0; substr($t, 8, 1) = $i;      # distinct instants, same era
    return { kind => 2, t => $t, body => $body, severity => 9, duration => 0,
             trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
             attrs => { 'service.name' => 'svc' } };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Four sealed segments of similar size, oldest first by name.
my @segs;
for my $i (0 .. 3) {
    Punk::Observe::WAL::append($store->wal_path,
        [ map { logline($i, "seg $i line $_ " . ('x' x 64)) } 0 .. 9 ], 0, 0);
    push @segs, scalar $store->seal;
}
my $total = 0;
$total += -s $_ for @segs;
my $one = -s $segs[0];

# --- the budget deletes oldest-first, sidecars in pairs ----------------------
{
    # Room for roughly two segments: the two oldest go.
    my $budget = $one * 2 + 8;
    my $out = Punk::Observe::Retain::pass(
        store => $store, keep_ns => '999999999999999999', bytes => $budget);

    is($out->{marked}, 0, 'the window kept everything');
    is($out->{budget_deleted}, 2, 'the budget deleted the two oldest');
    ok(!-e $segs[0] && !-e $segs[1], '  those two');
    ok(-e $segs[2] && -e $segs[3], '  and only those');
    for my $gone (@segs[0, 1]) {
        (my $idx = $gone) =~ s/\.seg\z/.idx/;
        ok(!-e $idx, '  its sidecar went with it');
    }
    cmp_ok($out->{bytes}, '<=', $budget, 'the store now fits the budget');
    is($out->{unlinked}, 2, 'the headline count includes budget deletions');
    ok($out->{budget_freed} > 0, '  and the freed bytes are reported');
}

# --- no budget, no budget stage ----------------------------------------------
{
    my $out = Punk::Observe::Retain::pass(
        store => $store, keep_ns => '999999999999999999');
    ok(!exists $out->{budget_deleted}, 'absent bytes, the stage never runs');
    ok(-e $segs[2] && -e $segs[3], '  and nothing else was deleted');
}

# --- dry_run must not delete, and says the budget was skipped ----------------
{
    my $out = Punk::Observe::Retain::pass(
        store => $store, keep_ns => '999999999999999999',
        bytes => 1, dry_run => 1);
    is($out->{budget_skipped}, 'dry_run', 'a dry run skips the budget stage');
    ok(-e $segs[2] && -e $segs[3], '  and deleted nothing');
}

# --- refusals name the field -------------------------------------------------
{
    my $err = do {
        local $@;
        eval { Punk::Observe::Retain::pass(
            store => $store, keep_ns => '1', bytes => 'lots') };
        $@;
    };
    like($err, qr/bytes 'lots'/, 'a garbage budget is refused by name');
}

# --- the plugin parses sizes, loudly -----------------------------------------
{
    my $r = Punk::Plugin::Observe::_retain({
        retain => { keep => '48h', bytes => '2G' } });
    is($r->{bytes}, 2 * 1024**3, "'2G' is two gibibytes");

    $r = Punk::Plugin::Observe::_retain({
        retain => { keep => '48h', bytes => '500M' } });
    is($r->{bytes}, 500 * 1024**2, "'500M' is five hundred mebibytes");

    $r = Punk::Plugin::Observe::_retain({
        retain => { keep => '48h', bytes => 1048576 } });
    is($r->{bytes}, 1048576, 'a plain byte count passes through');

    $r = Punk::Plugin::Observe::_retain({ retain => { keep => '48h' } });
    ok(!exists $r->{bytes}, 'no bytes asked for, none configured');

    my $err = do {
        local $@;
        eval { Punk::Plugin::Observe::_retain({
            retain => { keep => '48h', bytes => 'plenty' } }) };
        $@;
    };
    like($err, qr/retain bytes 'plenty'/,
         'a size that does not parse is a boot failure naming the field');
}

done_testing();
