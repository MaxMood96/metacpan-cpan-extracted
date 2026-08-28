use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;
use File::Temp qw(tempfile);
my (undef, $SAVE) = tempfile(UNLINK => 1);   # save_cookies was the ONE op family missing from this battery

# quit() must resolve EVERY in-flight async callback exactly once with
# 'browser closed', never silently drop it. Before this, only wait_for and
# navigation callbacks were flushed; an in-flight script/find/html/screenshot/
# cookie op had its GAsyncReadyCallback completion swallowed by _defer's
# dead-gate on quit -- a silent dropped callback that would hang a caller
# awaiting it. Each op below is fired and then quit() is called in the SAME
# tick, so the op is guaranteed still in flight when teardown happens.

my $b = EV::WebKit->new(window=>[200,200]);
$b->mock_scheme('q', sub { ('<html><body><div id="x">X</div></body></html>','text/html') });

my (%fired, %err, %count);
my $rec = sub { my ($label) = @_; return sub { my (undef,$e)=@_; $count{$label}++; $fired{$label}=1; $err{$label}=$e } };

my $ready = 0;
my $settle;   # hoisted: a watcher whose ONLY reference is inside the callback that made it dies with that callback
$b->go('q://p', sub {
    my (undef,$e)=@_;
    return EV::break if $e;
    $ready = 1;

    # A batch of DIFFERENT op families, all in flight, then quit() in the same tick.
    $b->find('#x',                       $rec->('find'));
    $b->find_all('div',                  $rec->('find_all'));
    $b->script('return 1;',              $rec->('script'));
    $b->script_async('return A.n;', {n=>7}, $rec->('script_async'));
    $b->html(                            $rec->('html'));
    $b->screenshot({bytes=>1},           $rec->('screenshot'));
    $b->cookies('http://example.com/',   $rec->('cookies'));
    $b->set_cookie({name=>'a',value=>'b',domain=>'example.com'}, $rec->('set_cookie'));
    $b->clear_cookies(                   $rec->('clear_cookies'));
    $b->save_cookies($SAVE, ['http://example.com/'], $rec->('save_cookies'));
    # The later op families. This battery's whole premise is that EVERY op
    # family is flushed, and these four were added to the module without being
    # added here. They also exercise two different flush paths: press/scroll
    # and download resolve through {_ops} and the download registries, while
    # wait_for/wait_for_js resolve through {_waiters}.
    # download needs no server: quit lands in this same tick, so the request is
    # still parked, unclaimed, and it is the parked entry that must be flushed.
    $b->download('http://127.0.0.1:1/never', '/tmp/evwk-flush-test.bin', $rec->('download'));
    $b->press('Enter',                   $rec->('press'));
    $b->scroll(y => 10, cb =>            $rec->('scroll'));
    $b->wait_for('#never-there',         $rec->('wait_for'));
    $b->wait_for_js('window.never',      $rec->('wait_for_js'));
    # resize resolves through _poll_until like wait_for, but wraps its
    # completion to turn a TIMEOUT into a size rather than an error -- a wrapper
    # that collapsed 'browser closed' into the same branch and reported a
    # phantom (undef size, no error) success here.
    $b->resize(320, 240,                 $rec->('resize'));
    $b->wait_for_navigation(              $rec->('wait_for_navigation'));

    $b->quit;    # tear down while all seventeen are in flight

    # Let any stray late completion try (and fail) to deliver a second time.
    # $settle is declared ABOVE this callback on purpose: a watcher referenced
    # only by a lexical inside the callback that created it is collected the
    # moment that callback returns, so it never fires and this block ran to the
    # 25s watchdog below instead -- a 2s settle that was really 25s, and would
    # silently become 3s if anyone shortened the watchdog. (Both spellings pass
    # the assertions, which is why it went unnoticed twice; the tell is the
    # file's runtime.)
    $settle = EV::timer(2, 0, sub { EV::break });
});

my $wd = EV::timer(25, 0, sub { EV::break });
EV::run;
undef $wd;

ok($ready, 'setup: navigated') or BAIL_OUT('no page');

my @ops = qw(find find_all script script_async html screenshot cookies set_cookie clear_cookies save_cookies
             download press scroll wait_for wait_for_js resize wait_for_navigation);
for my $op (@ops) {
    ok($fired{$op}, "$op: in-flight callback fired after quit (not silently dropped)")
        or diag("$op callback never fired");
    # NB: this pins exactly-once AT QUIT -- it does not pin _op_track's dedupe guard
    # (quit clears {_ops} before firing, and _defer dead-gates the late real
    # completion, so no second fire can arrive by this route anyway). The dedupe is
    # load-bearing for the pdf watchdog instead -- see t/56 test 6, which is what
    # actually fails if it is removed.
    is($count{$op} // 0, 1, "$op: fired exactly once (no double-fire)")
        or diag("$op fired $count{$op} times");
    like($err{$op} // '', qr/browser closed/, "$op: resolved with 'browser closed'")
        or diag("$op err=" . ($err{$op} // '(undef)'));
}

# A second quit() must be a clean no-op (no re-flush, no crash).
eval { $b->quit; 1 } or fail('second quit() threw: ' . $@);
pass('second quit() is a clean no-op');

# load_cookies() delegates to N set_cookie() calls, each its own tracked op, so
# quit() flushes N+1 {_ops} entries in undefined order. The delegated ones must
# NOT let their aggregation deliver a fake (0-loaded, no-error) "success" ahead
# of load_cookies' own entry's 'browser closed'. Loop it: the pre-fix race
# surfaced ~8% of the time, so a batch reliably catches a regression.
{
    use File::Temp qw(tempfile);
    my ($jfh, $jar) = tempfile(UNLINK => 1);
    print $jfh '[', join(',', map {
        qq({"name":"c$_","value":"v$_","domain":"example.com","path":"/"})
    } 1..8), ']';
    close $jfh;

    my ($runs, $bad) = (24, 0);
    for my $i (1 .. $runs) {
        my $lb = EV::WebKit->new(window => [150, 150]);
        $lb->mock_scheme('lq', sub { ('<html><body>hi</body></html>', 'text/html') });
        my ($val, $err, $fired);
        my $settle;
        $lb->go('lq://p', sub {
            my (undef, $e) = @_;
            return EV::break if $e;
            $lb->load_cookies($jar, sub { ($val, $err) = @_; $fired++ });
            $lb->quit;   # tear down while the delegated set_cookie ops are in flight
            $settle = EV::timer(1, 0, sub { EV::break });
        });
        my $wd = EV::timer(15, 0, sub { EV::break });
        EV::run; undef $wd;
        $bad++ unless $fired && ($fired == 1) && (($err // '') =~ /browser closed/);
        diag("run $i: fired=".($fired//0)." val=".(defined $val?$val:'undef')." err=".($err//'undef'))
            unless $fired && $fired == 1 && (($err // '') =~ /browser closed/);
    }
    is($bad, 0, "load_cookies quit-teardown: all $runs runs resolved once with 'browser closed' (no fake-success race)");
}

done_testing;
