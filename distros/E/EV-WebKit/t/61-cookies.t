use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[300,200], ephemeral=>1);
my ($list, $after, $set_err, $cookies_err, $clear_err, $after_err);
$b->set_cookie({ name=>'sid', value=>'42', domain=>'example.com', path=>'/' }, sub {
    (undef, $set_err) = @_;
    $b->cookies('http://example.com/', sub {
        ($list, $cookies_err) = @_;
        $b->clear_cookies(sub {
            (undef, $clear_err) = @_;
            $b->cookies('http://example.com/', sub { ($after, $after_err) = @_; EV::break });
        });
    });
});
TWK::run_with_timeout(10);
ok(!defined $set_err, 'set_cookie: no error');
ok(!defined $cookies_err, 'cookies: no error');
ok(!defined $clear_err, 'clear_cookies: no error');
ok(!defined $after_err, 'cookies (after clear): no error');
ok(scalar(grep { $_->{name} eq 'sid' && $_->{value} eq '42' } @$list), 'cookie set + read back');
is(scalar(@$after), 0, 'cookies cleared');

# --- error paths: a spec/uri missing required data must degrade via the
# callback (undef, $err), never throw synchronously (GI raises uncaught on
# undef mandatory args) -- consistent with the module's "never throw for
# ordinary runtime failures" contract.
my $H = EV::WebKit->new(window=>[300,200], ephemeral=>1);

my $no_name_err;
my $no_name_ret = $H->set_cookie({ value=>'v', domain=>'d.test' }, sub { (undef, $no_name_err) = @_; EV::break });
is($no_name_ret, $H, 'set_cookie (missing name) returns $b');
TWK::run_with_timeout(5);   # error delivery is deferred to a clean tick, same as other early-error guards
like($no_name_err, qr/missing 'name'/, 'set_cookie without name errors via callback, no throw');

my $no_domain_err;
$H->set_cookie({ name=>'n', value=>'v' }, sub { (undef, $no_domain_err) = @_; EV::break });
TWK::run_with_timeout(5);
like($no_domain_err, qr/missing 'domain'/, 'set_cookie without domain errors via callback, no throw');

# a typo'd security flag (secur => instead of secure =>) must not be silently
# dropped -- the cookie would then be created WITHOUT the Secure attribute.
my $bad_key_err;
$H->set_cookie({ name=>'n', value=>'v', domain=>'d.test', secur=>1 },
    sub { (undef, $bad_key_err) = @_; EV::break });
TWK::run_with_timeout(5);
like($bad_key_err, qr/unknown key.*secur/, "set_cookie with a typo'd spec key errors via callback, no silent drop");

my $no_uri_err;
my $no_uri_ret = $H->cookies(undef, sub { (undef, $no_uri_err) = @_; EV::break });
is($no_uri_ret, $H, 'cookies(undef, ...) returns $b');
TWK::run_with_timeout(5);
like($no_uri_err, qr/uri required/, 'cookies(undef, ...) errors via callback, no throw');

$H->quit;

# The cookie ops have a watchdog on the instance {timeout}: a cancelled op must
# resolve 'timeout'. load_cookies delegates to one set_cookie per row -- if
# those are cancelled it must SAY so, not report a (0, undef) count that is
# indistinguishable from "the jar held no valid rows".
{
    require File::Temp;
    my ($jfh, $jar) = File::Temp::tempfile(UNLINK => 1);
    print $jfh '[{"name":"a","value":"1","domain":"example.com","path":"/"},'
             . '{"name":"b","value":"2","domain":"example.com","path":"/"}]';
    close $jfh;

    my $T = EV::WebKit->new(window => [200,150], timeout => 0);   # every op times out immediately
    my ($res, $err, $fired);
    my $wd = EV::timer(15, 0, sub { EV::break });
    $T->load_cookies($jar, sub { ($res, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    ok($fired, 'load_cookies: callback fired under a zero timeout');
    is($err, 'timeout', 'load_cookies: a cancelled load reports timeout (not a fake 0-loaded success)')
        or diag("res=" . (defined $res ? $res : '(undef)') . " err=" . ($err // '(undef)'));
    $T->quit;
}

# The module promises ONE timeout string across the whole API, so a caller can
# test $err eq 'timeout' uniformly. Only some ops had that pinned by a test --
# mutation testing changed cookies'/clear_cookies'/screenshot's string
# independently and the whole suite stayed green each time. Pin them directly.
{
    for my $case (
        ['cookies'       => sub { $_[0]->cookies('http://example.com/', $_[1]) }],
        ['clear_cookies' => sub { $_[0]->clear_cookies($_[1]) }],
        ['set_cookie'    => sub { $_[0]->set_cookie({name=>'t',value=>'1',domain=>'example.com'}, $_[1]) }],
        ['screenshot'    => sub { $_[0]->screenshot({bytes=>1}, $_[1]) }],
    ) {
        my ($name, $call) = @$case;
        # timeout => 0 arms the watchdog for the very next tick -- but it is
        # still a RACE: on a loaded machine the op can complete before the
        # watchdog cancels it, and then there is no error to check (seen live).
        # So retry until the watchdog actually wins, and assert only on a run
        # where it did. Retrying is not a fudge: the ONE thing under test is the
        # error STRING, and a run that completed successfully simply did not
        # exercise it.
        my ($err, $fired, $timed_out, $tries, $other) = (undef, 0, 0, 0, undef);
        while ($tries++ < 10) {
            my $T = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 0);
            ($err, $fired) = (undef, 0);
            my $wd = EV::timer(15, 0, sub { EV::break });
            $call->($T, sub { $fired++; $err = $_[1]; EV::break });
            EV::run; undef $wd;
            $T->quit;
            # An error that is NOT a cancellation means the op failed for its
            # own reasons -- seen on a headless CI runner, where get_snapshot
            # can fail under llvmpipe before the watchdog lands. That run did
            # not exercise the timeout path either, so keep trying rather than
            # asserting on it. The block below pins the literal deterministically,
            # so degrading to a skip here does not reopen the mutation this
            # block was written for.
            last if $timed_out = ($fired && defined $err && $err eq 'timeout');
            $other = $err if $fired && defined $err;
        }
        ok($fired, "$name: callback fired under a zero timeout");
      SKIP: {
            skip "$name: the watchdog never won in $tries tries (machine too fast/"
               . 'loaded, or the op failed on its own: '
               . ($other // 'no error at all') . ')', 1 unless $timed_out;
            is($err, 'timeout', "$name: uses the module's uniform 'timeout' error")
                or diag("err=" . ($err // '(undef)'));
        }
    }
}

# save_cookies($file, \@uris, $cb): a middle argument that is not an arrayref
# was never looked at again, so save_cookies($file, 'https://one.example/', $cb)
# reported SUCCESS having snapshotted every uri the instance had visited --
# the opposite scope from the one asked for, into a file that holds
# credentials. cookies($uri, $cb), the sibling, takes a bare string, which is
# exactly where that spelling comes from.
{
    require File::Temp;
    my $sc = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 10);
    $sc->mock_scheme('sc', sub { ('<p>x</p>', 'text/html') });
    my $ready = 0;
    $sc->go('sc://a', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: the instance has navigated somewhere');

    my $sdir = File::Temp::tempdir(CLEANUP => 1);
    my $f = "$sdir/scope.json";
    ok(!eval { $sc->save_cookies($f, 'http://only-this.example/', sub {}); 1 },
       'save_cookies croaks on a bare uri where a list belongs');
    like($@, qr/must be an array reference/, '...saying so');
    like($@, qr/cookies\(\) takes a bare uri/, '...and naming the sibling it was confused with');
    # Settle first: the write is deferred, so checking with zero loop turns in
    # between cannot fail in any world -- measured, the file appears one tick
    # later.
    { my $settle = EV::timer(1.0, 0, sub { EV::break }); EV::run }
    ok(!-e $f, '...having written nothing');

    # the documented spellings still work -- and SUCCEED, not merely answer
    my ($e1, $d1) = (undef, 0);
    $sc->save_cookies($f, ['sc://a'], sub { $e1 = $_[1]; $d1 = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($d1, 'save_cookies with an explicit list still answers') or diag 'no callback';
    is($e1, undef, '...without an error') or diag $e1;
    my ($e2, $d2) = (undef, 0);
    $sc->save_cookies("$sdir/scope2.json", sub { $e2 = $_[1]; $d2 = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($d2, 'save_cookies with the list omitted still answers') or diag 'no callback';
    is($e2, undef, '...without an error either') or diag $e2;
    $sc->quit;
}

# The live checks above degrade to a SKIP on a machine that never lets the
# watchdog win, so a changed literal could slip through there. Pin it at the
# source too: every cancellation branch in the module must resolve to exactly
# 'timeout'. Deterministic, and needs no browser.
{
    # %INC, not a guessed path: the file that is actually LOADED is the one
    # under test. Preferring blib/ read the wrong copy under an -I mutation
    # run, so the check passed while the literal really had changed.
    my $mod = $INC{'EV/WebKit.pm'} or die 'EV::WebKit is not loaded';
    open my $mh, '<', $mod or die "cannot read $mod: $!";
    my $code = do { local $/; <$mh> };
    close $mh;
    my @branches = $code =~ /is_cancelled \? (\S+)/g;
    cmp_ok(scalar @branches, '>=', 4, 'found the cancellation branches to check');
    my @wrong = grep { $_ ne "'timeout'" } @branches;
    is(scalar @wrong, 0, "every cancellation branch resolves the uniform 'timeout' string")
        or diag('these do not: ' . join(' | ', @wrong));
}

done_testing;
