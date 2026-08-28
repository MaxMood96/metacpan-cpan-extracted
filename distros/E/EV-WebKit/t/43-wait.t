use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[300,200]);
my ($found, $err2, $visible_found, $visible_after_show);
$b->load_html('<div id=host></div>'
            . '<div id=hidden style="display:none">hidden</div>'
            . '<script>'
            . 'setTimeout(()=>{'
            . '  document.getElementById("host").innerHTML="<b id=late>x</b>";'
            . '},300);'
            . 'setTimeout(()=>{'
            . '  document.getElementById("hidden").style.display="block";'
            . '},400);'
            . '</script>', sub {
    my $n = 0;
    my $done = sub { EV::break if ++$n == 3 };

    # Test 1: element appears late, wait_for resolves
    $b->wait_for('#late', timeout=>5, sub {
        my ($el) = @_;
        $el->tag(sub {
            $found = $_[0];
            $done->();
        });
    });

    # Test 2: selector never matches, timeout fires
    $b->wait_for('#never', timeout=>1, sub {
        $err2 = $_[1];
        $done->();
    });

    # Test 3: element exists but hidden, visible=>1 doesn't resolve until shown
    $b->wait_for('#hidden', visible=>1, timeout=>5, sub {
        my ($el) = @_;
        $visible_found = 1;
        $el->is_visible(sub {
            $visible_after_show = $_[0];
            $done->();
        });
    });
});
TWK::run_with_timeout(12);
is($found, 'b', 'wait_for resolved late element');
is($err2, 'timeout', 'wait_for times out for absent selector');
is($visible_found, 1, 'wait_for with visible=>1 resolved when element became visible');
is($visible_after_show, 1, 'element is visible when callback fires');

# --- regression: wait_for(interval=>0 or negative) must not busy-loop and
# starve the EV loop. $elapsed never advances when interval<=0, so the
# deadline check never trips and wait_for re-polls on a zero-delay timer
# forever; a non-positive interval must instead snap to the default at parse
# time. Each case gets its own bounded watchdog -- distinct from
# TWK::run_with_timeout's suite-wide one -- so a pre-fix regression fails
# fast with a clear "didn't resolve on its own" diagnosis instead of quietly
# riding out the whole suite's timeout (confirmed live: pre-fix, the
# callback only ever fires via quit()'s teardown path with 'browser closed',
# never with 'timeout', so it must not be allowed to reach that path here).
for my $case ([0, 'interval=>0'], [-1, 'interval=>-1']) {
    my ($interval, $label) = @$case;
    my $W = EV::WebKit->new(window=>[300,200]);
    my $ready = 0;
    $W->load_html('<div id=host></div>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(10);
    ok($ready, "$label: page ready");

    my ($werr, $watchdog_fired, $took);
    my $watchdog = EV::timer(6, 0, sub { $watchdog_fired = 1; EV::break });
    my $t0 = EV::time;
    $W->wait_for('#never', interval=>$interval, timeout=>1, sub {
        (undef, $werr) = @_;
        EV::break;
    });
    EV::run;
    $took = EV::time - $t0;
    undef $watchdog;

    ok(!$watchdog_fired, "$label: wait_for resolved on its own (no busy-loop hang)");
    is($werr, 'timeout', "$label: wait_for resolves 'timeout', not a hang");
    ok($took < 2.5, "$label: resolved quickly (took ${took}s), confirms no busy-loop stall")
        if defined $werr;
    $W->quit;
}

# --- regression: wait_for's visible=>1 poll must propagate a REAL is_visible
# error instead of silently treating it as "not visible yet" and surfacing a
# misleading plain 'timeout' much later. is_visible is made to throw a real
# script error on demand, still through the actual _call_js/GI/JS-error
# pipeline (only the JS snippet is substituted -- not the delivery mechanism,
# and not the assertion).
{
    my $b = EV::WebKit->new(window=>[300,200]);
    $b->load_html('<div id="x" style="display:none">hi</div>', sub { EV::break });
    TWK::run_with_timeout(10);

    no warnings 'redefine';
    local *EV::WebKit::Element::is_visible = sub {
        my ($el, $cb) = @_;
        $el->_call_js('throw new Error("kaboom (forced for test)");', {}, $cb);
    };

    my ($res_el, $res_err, $took);
    my $t0 = EV::time;
    $b->wait_for('#x', visible => 1, timeout => 1, sub {
        ($res_el, $res_err) = @_;
        $took = EV::time - $t0;
        EV::break;
    });
    TWK::run_with_timeout(10);

    is($res_el, undef, 'wait_for: is_visible error -> no element result');
    like($res_err // '', qr/kaboom/, 'wait_for: is_visible error propagates as the real error, not swallowed into timeout')
        or diag("res_err=" . ($res_err // 'u'));
    ok((defined $took && $took < 0.5), 'wait_for: resolved promptly on the is_visible error (did not ride out the full timeout)')
        or diag("took=" . ($took // 'u'));

    $b->quit;
}

# --- ...but a STALE element is NOT a real error here, and must NOT end the
# wait. visible=>1 needs two round-trips (find(), then is_visible() on that
# handle), and the page can change the node in between -- __evwk.get throws
# 'stale element' both when the node was detached (isConnected false) and when
# the page navigated (epoch mismatch). Either way it is transient with respect
# to the poll loop, because the NEXT tick does a fresh find(): treating it as
# terminal made wait_for(visible=>1) fail outright on any page that re-renders
# the node it is waiting for -- exactly the pages wait_for exists for. Poll
# through it; if the element never settles, the honest answer is 'timeout'.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    $b->load_html('<div id="x">hi</div>', sub { EV::break });
    TWK::run_with_timeout(10);

    my $throws = 3;    # go stale for the first few polls, then settle
    no warnings 'redefine';
    local *EV::WebKit::Element::is_visible = sub {
        my ($el, $cb) = @_;
        return $el->_call_js('throw new Error("stale element");', {}, $cb) if $throws-- > 0;
        $el->_call_js('return true;', {}, $cb);
    };

    my ($res_el, $res_err);
    $b->wait_for('#x', visible => 1, timeout => 5, sub { ($res_el, $res_err) = @_; EV::break });
    TWK::run_with_timeout(15);

    is($res_err, undef, 'wait_for: a stale handle mid-poll is not an error -- it keeps polling')
        or diag("res_err=" . ($res_err // 'u') . " (a churning page must not break wait_for)");
    ok($res_el, '...and it resolves once the element settles');
    ok($throws <= 0, '...having actually gone through the stale polls');

    $b->quit;
}

# wait_for is find() on a poll, so it must validate like find(): unknown option
# keys and a bad selector both croak, up front.
#
# The typo case is not a weaker wait, it is an INVERTED one. `gone => 1` waits
# for the selector to match nothing; with the key dropped, $gone stays undef and
# the very first poll resolves successfully WITH the element -- so
# `wait_for('#spinner', gnoe => 1)` reported "the spinner is gone" while it was
# still on screen. Same for visble/visible.
#
# The selector case is worse than a bad message: _poll_until registers the
# waiter and arms the deadline BEFORE the first tick, so a croak raised from the
# find() inside the probe escaped to the caller AND left the timer running --
# one call delivering twice, a synchronous die plus a stray 'timeout' later.
{
    my $b2 = EV::WebKit->new(window => [200,150], timeout => 5);
    my $ready = 0;
    $b2->load_html('<div id=spin>s</div>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(15);
    ok($ready, 'premise: the page is loaded');

    for my $bad (qw(gnoe visble frmae)) {
        ok(!eval { $b2->wait_for('#spin', $bad => 1, timeout => 1, sub { }); 1 },
           "wait_for croaks on the unknown option '$bad'");
        like($@, qr/unknown option\(s\): \Q$bad\E/, '...naming it');
    }
    ok(!eval { $b2->wait_for_js('1', intrval => 1, sub { }); 1 },
       'wait_for_js croaks on an unknown option too');
    like($@, qr/unknown option\(s\): intrval/, '...naming it');

    # A dropped VALUE leaves an odd option list. Left to `%o = @_` that warns
    # "Odd number of elements in hash assignment" from inside the module and
    # then blames the caller for an unknown option whose name is really their
    # own dropped value -- so say what actually went wrong. It also matters
    # over the socket: press keyed callback detection on parity for one round,
    # and an even count there swallowed the server's reply callback into %o,
    # hanging the client.
    for my $case ([ 'wait_for'            => sub { $b2->wait_for('#spin', 'timeout', sub {}) } ],
                  [ 'wait_for_js'         => sub { $b2->wait_for_js('1', 'timeout', sub {}) } ],
                  # Any key does here: with the pairs guard removed, the croak
                  # comes from a different check but the MESSAGE and warning
                  # assertions below still catch it. (Measured: 'timeout' and
                  # 'zzz' fail exactly the same two of the three.)
                  [ 'wait_for_navigation' => sub { $b2->wait_for_navigation('zzz', sub {}) } ],
                  [ 'press'               => sub { $b2->press('a', 'shift', sub {}) } ]) {
        my ($name, $call) = @$case;
        my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
        ok(!eval { $call->(); 1 }, "$name croaks on an odd option list");
        like($@, qr/options must be name => value pairs/, '...saying what is wrong');
        is(scalar(@w), 0, '...without warning from inside the module first');
    }

    # a legitimate option list still works -- and resolves, so the guard cannot
    # be passing by rejecting everything
    my ($lel, $lerr, $ldone) = (undef, undef, 0);
    ok(eval { $b2->wait_for('#spin', visible => 1, interval => 0.05, timeout => 3,
                            sub { ($lel, $lerr) = @_; $ldone = 1; EV::break }); 1 },
       'a legitimate wait_for option list is still accepted') or diag $@;
    { my $t = EV::timer(5, 0, sub { EV::break }); EV::run }
    ok($ldone && $lel && !$lerr, '...and still resolves with the element')
        or diag('done=' . ($ldone ? 1 : 0) . ' err=' . ($lerr // 'undef'));

    # the selector, up front and exactly once
    for my $case ([ undef, 'undef', qr/a selector is required/ ],
                  [ '',    'the empty string', qr/must not be empty/ ]) {
        my ($sel, $label, $want) = @$case;
        my $fired = 0;
        ok(!eval { $b2->wait_for($sel, timeout => 0.4, sub { $fired++; EV::break }); 1 },
           "wait_for($label) croaks");
        like($@, $want, '...saying why');
        like($@, qr/^wait_for:/, '...as wait_for, not as the find() inside its probe');
        my $t = EV::timer(1.2, 0, sub { EV::break });
        EV::run;
        is($fired, 0, '...and does NOT also deliver a stray timeout afterwards');
    }
    $b2->quit;
}

# scroll's callback is a NAMED option (cb => ...), which made it the one async
# method whose natural trailing-callback spelling misfired: the coderef landed
# in %o as a KEY, warned "Odd number of elements" from inside the module, and
# then blamed the caller for an unknown option named after their own callback.
# Both spellings must work now, and the named one is what Control still uses.
{
    my $b4 = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 8);
    my $ready = 0;
    $b4->load_html('<body style="height:3000px">t</body>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: a scrollable page is loaded');

    for my $spell (['positional', sub { $b4->scroll(y => 10, $_[0]) }],
                   ['cb => ...',  sub { $b4->scroll(y => 10, cb => $_[0]) }]) {
        my ($name, $call) = @$spell;
        my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
        my ($r, $e, $done) = (undef, undef, 0);
        # eval'd: without it, a regression here croaks and takes the rest of the
        # file with it (exit 17, no plan) instead of failing one named assertion.
        my $accepted = eval { $call->(sub { ($r, $e) = @_; $done = 1; EV::break }); 1 };
        ok($accepted, "scroll($name): the call is accepted") or diag $@;
        TWK::run_with_timeout(15) if $accepted;
        ok($done, "scroll($name): the callback fires");
        is($e, undef, "scroll($name): without an error") or diag $e;
        is(ref $r, 'HASH', "scroll($name): resolving with the position");
        is(scalar(@w), 0, "scroll($name): and nothing warned from inside the module");
    }
    ok(!eval { $b4->scroll(y => 10, 'notacb'); 1 }, 'scroll still rejects a non-coderef callback');
    like($@, qr/cb must be a code reference/, '...saying so');
    # `by` is read as a bare truthy flag and never validated, so scroll(by=>$cb)
    # is an EVEN list: a parity-only rule does not pop, the coderef becomes by's
    # value, $cb stays undef, every check passes, and nothing is ever called.
    # This is the shape that proves the ref half of the rule is load-bearing.
    ok(!eval { $b4->scroll(by => sub {}); 1 }, 'scroll(by => $cb) croaks rather than swallowing the callback');
    like($@, qr/name => value pairs/, '...as a malformed option list');
    # Both spellings at once used to delete the named one silently, leaving
    # whoever was waiting on it hung -- the failure this module croaks over
    # everywhere else.
    ok(!eval { $b4->scroll(y => 20, cb => sub {}, sub {}); 1 },
       'scroll croaks when the callback is passed both ways');
    like($@, qr/pass the callback once/, '...saying to pick one');
    $b4->quit;
}

# wait_for with a frame => must WAIT FOR THE FRAME, not just for the selector
# inside an already-present one. A page that injects its payment iframe a
# moment after load is the documented reason wait_for takes a frame at all, and
# it used to fail at 0.00s with 'no frame matched url' / 'frame not found'.
# And gone => 1 must succeed when the frame itself is removed -- an overlay
# usually disappears by having its whole iframe taken out -- rather than
# reporting an error for the condition the caller was waiting for.
#
# This is the twin of the 'stale element' rule in the same probe: a thing not
# being there yet is "not settled", not a failure.
{
    my $fb = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 12);
    $fb->mock_scheme('wff', sub {
        my $u = shift;
        return ('<html><body><p id=card>CARD</p><div id=spin>S</div></body></html>', 'text/html')
            if $u =~ m{inner};
        return ('<html><body><script>setTimeout(function(){'
              . 'var f=document.createElement("iframe");f.id="late";'
              . 'f.src="wff://host/inner";document.body.appendChild(f)},700)'
              . '</script></body></html>', 'text/html');
    });
    my $ready = 0;
    $fb->go('wff://host/outer', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(25);
    ok($ready, 'premise: the opener page loaded (the iframe comes 0.7s later)');

    # The url form is answered by the web-process extension; the selector form
    # walks contentDocument from main-frame script and needs nothing. So the
    # url case only runs where the extension was built (the CI matrix has a leg
    # that deliberately builds without it).
    require EV::WebKit::Fingerprint;
    my $ext = EV::WebKit::Fingerprint::available();
    my @spellings = (['selector form', sub { $fb->wait_for('#card', frame => '#late', timeout => 10, $_[0]) }]);
    unshift @spellings, ['url form', sub { $fb->wait_for('#card', frame => { url => qr/inner/ }, timeout => 10, $_[0]) }]
        if $ext;
    diag('web-process extension absent -- skipping the frame => { url => } spelling') unless $ext;

    for my $spell (@spellings) {
        my ($name, $call) = @$spell;
        my ($r, $e, $d) = (undef, undef, 0);
        $call->(sub { ($r, $e) = @_; $d = 1; EV::break });
        TWK::run_with_timeout(20);
        ok($d, "wait_for into a late frame ($name) answers") or diag 'no callback';
        is($e, undef, "...without an error") or diag $e;
        isa_ok($r, 'EV::WebKit::Element', "...with the element from inside the frame");
    }

    # ...and the frame going away is what gone => 1 was waiting for
    $fb->script('document.getElementById("late").remove(); return 1;', sub { EV::break });
    TWK::run_with_timeout(15);
    my ($gr, $ge, $gd) = (undef, undef, 0);
    $fb->wait_for('#spin', frame => '#late', gone => 1, timeout => 8,
                  sub { ($gr, $ge) = @_; $gd = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($gd, 'gone => 1 answers once the whole frame is removed') or diag 'no callback';
    is($ge, undef, '...without an error') or diag $ge;
    ok($gr, '...resolving true, which is what the caller waited for');
    $fb->quit;
}

# ...but a frame named by { id => } is the exception to that rule. The
# extension calls frames_forget() on the very reply that says the frame is
# gone, so the id can never name anything again and polling it could only ever
# reach the timeout. It must fail at once instead.
SKIP: {
    require EV::WebKit::Fingerprint;
    skip 'web-process extension absent -- the { id => } form needs it', 6
        unless EV::WebKit::Fingerprint::available();

    my $ib = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 12);
    $ib->mock_scheme('wfi', sub { ('<html><body><p id=card>C</p></body></html>', 'text/html') });
    $ib->go('wfi://host/p', sub { EV::break });
    TWK::run_with_timeout(25);

    my $dead = 987654321;   # never handed out: the extension answers 'frame is gone'
    my $t0 = EV::time;
    my ($r, $e, $d) = (undef, undef, 0);
    $ib->wait_for('#card', frame => { id => $dead }, timeout => 6,
                  sub { ($r, $e) = @_; $d = 1; EV::break });
    TWK::run_with_timeout(20);
    my $took = EV::time - $t0;
    ok($d, 'wait_for on a dead frame id answers') or diag 'no callback';
    like($e, qr/frame is gone/, '...with the real reason, not a bare timeout') or diag $e // 'undef';
    cmp_ok($took, '<', 3, '...and at once, rather than polling out the timeout') or diag "took ${took}s";

    # gone => 1 keeps its own meaning here: the selector inside a frame that is
    # not there matches nothing, which is exactly the waited-for condition.
    $t0 = EV::time;
    my ($gr, $ge, $gd) = (undef, undef, 0);
    $ib->wait_for('#card', frame => { id => $dead }, gone => 1, timeout => 6,
                  sub { ($gr, $ge) = @_; $gd = 1; EV::break });
    TWK::run_with_timeout(20);
    $took = EV::time - $t0;
    ok($gd, 'gone => 1 on a dead frame id answers') or diag 'no callback';
    is($ge, undef, '...without an error') or diag $ge;
    ok($gr && $took < 3, '...resolving true straight away');
    $ib->quit;
}

# ...and the url form is still the url form when it carries an explicit undef
# id. _frames_arg accepts that spelling (it requires exactly one of the two
# DEFINED) and _resolve_frame routes it by defined-ness, so wait_for must poll
# through the missing frame like any url form -- not read the bare presence of
# an id key as the { id => } form and fail at once.
SKIP: {
    require EV::WebKit::Fingerprint;
    skip 'web-process extension absent -- the { url => } form needs it', 3
        unless EV::WebKit::Fingerprint::available();

    my $ub = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 12);
    $ub->mock_scheme('wfu', sub { ('<html><body><p id=card>C</p></body></html>', 'text/html') });
    $ub->go('wfu://host/p', sub { EV::break });
    TWK::run_with_timeout(25);

    my $t0 = EV::time;
    my ($r, $e, $d) = (undef, undef, 0);
    $ub->wait_for('#card', frame => { url => qr/never-appears/, id => undef }, timeout => 4,
                  sub { ($r, $e) = @_; $d = 1; EV::break });
    TWK::run_with_timeout(20);
    my $took = EV::time - $t0;
    ok($d, 'wait_for on a url form carrying an undef id answers') or diag 'no callback';
    is($e, 'timeout', '...by waiting out its timeout, as the url form must') or diag $e // 'undef';
    cmp_ok($took, '>', 3, '...rather than failing at once like a dead id') or diag "took ${took}s";
    $ub->quit;
}

done_testing;
