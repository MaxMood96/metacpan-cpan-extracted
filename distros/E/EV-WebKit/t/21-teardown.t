use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# 1) white-box regression: quit() during the settle window must not crash
#    reading a torn-down view -- and must still RESOLVE the nav callback.
#
#    _finish_nav deletes {pending} and only then hands the callback to the
#    settle timer, so for that ~30ms window it belongs to no registry. quit()
#    stops the timer (rightly -- it would report success on a torn-down browser
#    and touch a dead view), and the callback used to simply vanish: a go() that
#    succeeded and was quit() within the settle window never called back at all,
#    a silent hang for anyone awaiting it. Suppressing the SUCCESS delivery was
#    right; dropping the callback was not. It is now tracked, so quit()'s flush
#    resolves it exactly once with 'browser closed', like every other in-flight
#    op (see t/50-quit-flush.t), and the settle timer stays cancelled.
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($fired, $ok, $err) = (0);
    $b->{pending} = [ sub { $fired++; ($ok, $err) = @_ }, undef ];   # simulate an in-flight nav
    $b->_finish_nav(undef);                          # success -> schedules the settle timer
    $b->quit;                                        # tear down during the settle window
    my $w = EV::timer(0.05, 0, sub { EV::break });   # wait past NAV_SETTLE_DELAY
    EV::run;
    is($fired, 1, 'nav callback resolved exactly once by quit() during the settle window');
    ok(!$ok && ($err // '') eq 'browser closed',
        "...with 'browser closed' -- never the success it was about to report on a dead view")
        or diag("ok=" . ($ok // '(undef)') . " err=" . ($err // '(undef)'));
    pass('no crash tearing down during settle window');
}

# 2) sequential instances: window ->destroy + Xvfb teardown must allow a fresh instance.
{
    my $err1;
    my $b1 = EV::WebKit->new(window=>[200,150]);
    $b1->load_html('<title>one</title>', sub { (undef,$err1)=@_; EV::break });
    TWK::run_with_timeout(10);
    is($err1, undef, 'first instance loads');
    $b1->quit;

    my ($err2, $title2);
    my $b2 = EV::WebKit->new(window=>[200,150]);
    $b2->load_html('<title>two</title>', sub { (undef,$err2)=@_; $title2=$b2->title; EV::break });
    TWK::run_with_timeout(10);
    is($err2, undef, 'second instance loads after first quit');
    is($title2, 'two', 'second instance sees its own title');
    $b2->quit;
}

# 3) failed navigation surfaces an error to the callback.
{
    my $b = EV::WebKit->new(window=>[200,150], timeout=>4);
    my ($r,$e);
    $b->go('http://nonexistent.invalid./', sub { ($r,$e)=@_; EV::break });
    TWK::run_with_timeout(10);
    ok(defined $e, 'failed navigation reports an error (or times out)') or diag "r=".($r//'undef');
    $b->quit;
}

# 4) post-quit contract: sync accessors degrade, async ops resolve with 'browser closed'
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($we, $n1, $n2) = (undef, 0, 0);

    # settle-slot independence: two navs resolved back-to-back within the settle window
    $b->{pending} = [ sub { $n1++ }, undef ];
    $b->_finish_nav(undef);
    $b->{pending} = [ sub { $n2++ }, undef ];
    $b->_finish_nav(undef);
    # Derive the wait from the settle deadline: these navs are driven straight
    # through _finish_nav with no view behind them, so no notify::title can
    # arrive and the deadline is their only arm. A hardcoded wait silently
    # becomes too short the moment that constant is raised.
    my $t1 = EV::timer(EV::WebKit::NAV_SETTLE_DELAY() + 0.05, 0, sub { EV::break });
    EV::run;
    is($n1, 1, 'first nav settle callback fired despite overlapping second');
    is($n2, 1, 'second nav settle callback fired');

    $b->quit;
    is($b->uri, undef, 'uri after quit -> undef, no die');
    is($b->title, undef, 'title after quit -> undef');
    is($b->is_loading, 0, 'is_loading after quit -> 0');
    is($b->set_user_agent('x'), $b, 'set_user_agent after quit -> no-op self');
    is($b->settings({enable_javascript=>1}), $b, 'settings after quit -> no-op self');
    is($b->set_proxy('no-proxy'), $b, 'set_proxy after quit -> no-op self');
    is($b->mock_scheme('m', sub {}), $b, 'mock_scheme after quit -> no-op self');

    my ($ge, $le, $se, $sce, $fe, $he);
    is($b->go('http://x.invalid/', sub { (undef, $ge) = @_ }), $b, 'go after quit returns $b');
    is($b->load_html('<html></html>', sub { (undef, $le) = @_ }), $b, 'load_html after quit returns $b');
    is($b->screenshot({bytes=>1}, sub { (undef, $se) = @_ }), $b, 'screenshot({bytes=>1}) after quit returns $b');
    is($b->wait_for('#x', sub { (undef, $we) = @_; EV::break }), $b, 'wait_for after quit returns $b');
    # _call_js's own dead-guard (shared by script/script_async/find/find_all/html) --
    # unlike the above, none of these have their own dead-guard; they rely
    # entirely on _call_js's. script/html are documented to return $b; find has
    # no such contract (see POD), so only its callback delivery is asserted.
    is($b->script('return 1', sub { (undef, $sce) = @_ }), $b, 'script after quit returns $b');
    $b->find('#x', sub { (undef, $fe) = @_ });
    is($b->html(sub { (undef, $he) = @_ }), $b, 'html after quit returns $b');
    my $t2 = EV::timer(2, 0, sub { EV::break });
    EV::run;
    is($ge, 'browser closed', 'go after quit resolves with browser closed');
    is($le, 'browser closed', 'load_html after quit resolves with browser closed');
    is($se, 'browser closed', 'screenshot after quit resolves with browser closed');
    is($we, 'browser closed', 'wait_for after quit resolves with browser closed');
    is($sce, 'browser closed', 'script after quit resolves with browser closed');
    is($fe, 'browser closed', 'find after quit resolves with browser closed');
    is($he, 'browser closed', 'html after quit resolves with browser closed');
}

# 5) wait_for's post-quit behavior must be deterministic: an outstanding
#    wait_for always resolves exactly once with 'browser closed' when the
#    browser quits mid-wait, regardless of whether quit() lands in the
#    between-poll gap or while a poll's find() is still in flight.
{
    # (a) quit() mid-GAP -- lands while waiting for the next scheduled poll
    #     (interval 0.3s, quit at 0.15s: well inside the gap). Spin long
    #     enough (0.6s) that the original (now-cancelled) poll timer at 0.3s
    #     would also have fired, to prove there is no double delivery.
    my $ba = EV::WebKit->new(window=>[200,150]);
    my ($n_a, $err_a) = (0, undef);
    my @keep_a;
    $ba->load_html('<p>x</p>', sub {
        $ba->wait_for('#never', interval=>0.3, sub { $n_a++; $err_a = $_[1] });
        push @keep_a, EV::timer(0.15, 0, sub { $ba->quit });
        push @keep_a, EV::timer(0.6, 0, sub { EV::break });
    });
    TWK::run_with_timeout(10);
    is($n_a, 1, 'quit() mid-gap: outstanding wait_for delivered exactly once');
    is($err_a, 'browser closed', "quit() mid-gap: wait_for resolves with 'browser closed'");
}

{
    # (b) quit() mid-FIND -- called synchronously right after wait_for(), so
    #     the very first find() is still in flight (its GI async completion
    #     has not arrived yet) when quit() tears the browser down.
    my $bb = EV::WebKit->new(window=>[200,150]);
    my ($n_b, $err_b) = (0, undef);
    my @keep_b;
    $bb->load_html('<p>x</p>', sub {
        $bb->wait_for('#never', interval=>0.05, sub { $n_b++; $err_b = $_[1] });
        $bb->quit;
        push @keep_b, EV::timer(0.5, 0, sub { EV::break });
    });
    TWK::run_with_timeout(10);
    is($n_b, 1, 'quit() mid-find: outstanding wait_for delivered exactly once');
    is($err_b, 'browser closed', "quit() mid-find: wait_for resolves with 'browser closed'");
}
done_testing;
