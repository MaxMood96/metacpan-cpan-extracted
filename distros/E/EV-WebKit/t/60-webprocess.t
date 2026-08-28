use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# 1) The renderer can die -- it crashes, hits its memory limit, or is killed.
#    WebKit says so immediately (web-process-terminated), but sends no
#    load-failed for the page that was loading. Ignoring that signal meant an
#    in-flight navigation sat there for the WHOLE timeout (30s by default) and
#    then reported 'timeout' -- for something that became impossible the instant
#    the process died.
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 20);
    $b->mock_scheme('wp', sub { ('<html><body><h1>hi</h1></body></html>', 'text/html') });

    my ($err, $fired, $took);
    my $t0 = EV::time;
    $b->go('wp://p', sub { $err = $_[1]; $fired++; $took = EV::time - $t0; EV::break });
    my $kill = EV::timer(0.05, 0, sub { $b->{view}->terminate_web_process });
    my $wd = EV::timer(25, 0, sub { EV::break });
    EV::run; undef $wd; undef $kill;

    is($fired, 1, 'a navigation whose web process dies resolves exactly once');
    like($err // '', qr/web process terminated/,
        '...saying the web process died, not a misleading "timeout"')
        or diag("err=" . ($err // '(none)'));
    ok(defined $took && $took < 5,
        '...and promptly, instead of waiting out the full timeout')
        or diag(sprintf('took %.1fs of a 20s timeout', $took // -1));
    $b->quit;
}

# 2) With no navigation pending, the crash must still not be silent: it reaches
#    on_error, like any other failure with nobody waiting on it.
{
    my @errs;
    my $b = EV::WebKit->new(window => [300,200], timeout => 20,
                            on_error => sub { push @errs, $_[0] });
    $b->load_html('<p>loaded</p>', sub { EV::break });
    TWK::run_with_timeout(15);

    $b->{view}->terminate_web_process;          # nothing in flight
    my $wd = EV::timer(3, 0, sub { EV::break }); EV::run; undef $wd;

    is(scalar(grep { /web process terminated/ } @errs), 1,
        'a crash with no navigation pending is reported to on_error (never silent)')
        or diag('on_error saw: ' . (join(' | ', @errs) || '(nothing)'));
    $b->quit;
}

# 3) The element registry must not grow without bound. Every find() registers
#    the node it matched -- and wait_for re-runs find() on every poll, 20 times
#    a second by default -- so a page that never navigates (a long-lived SPA:
#    exactly what this module automates) accumulated one entry per call forever,
#    each one pinning its DOM node in the renderer's JS heap.
{
    my $b = EV::WebKit->new(window => [300,200]);
    my $ready;
    $b->load_html('<div id="d">hi</div><div class="gone">x</div>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(15);
    ok($ready, 'setup: page loaded') or BAIL_OUT('no page');

    # the same node, found over and over
    my $n = 0;
    my $chain; $chain = sub {
        $b->find('#d', sub { ++$n >= 200 ? EV::break : $chain->() });
    };
    $chain->();
    TWK::run_with_timeout(60);
    undef $chain;
    is($n, 200, 'setup: found the same node 200 times');

    my ($size, $serr);
    $b->script_async('return window.__evwk.h.size;', {}, sub { ($size, $serr) = @_; EV::break });
    TWK::run_with_timeout(15);
    # (script_async runs in the MAIN world, where __evwk is invisible by design)
    $size = undef;
    $b->_call_js('return window.__evwk.h.size;', {}, sub { ($size, $serr) = @_; EV::break });
    TWK::run_with_timeout(15);

    is($size, 1, 'finding the same node 200 times registers it ONCE (deduped, not 200 entries)')
        or diag("registry holds $size entries after 200 identical find()s");

    # a detached node must not be pinned forever either
    $b->script('document.querySelector(".gone").remove()', sub { EV::break });
    TWK::run_with_timeout(15);
    my $swept;
    $b->_call_js(q{
        for (let i = 0; i < 200; i++) { const d = document.createElement('div'); document.body.appendChild(d); window.__evwk.put(d); d.remove(); }
        window.__evwk.put(document.body);
        return window.__evwk.h.size;
    }, {}, sub { $swept = $_[0]; EV::break });
    TWK::run_with_timeout(15);
    ok(defined $swept && $swept < 100,
        'detached nodes are swept out of the registry (not pinned for the life of the page)')
        or diag("registry still holds $swept entries after 200 detached nodes");

    # ...and none of that may break the handles themselves
    my ($txt, $terr);
    $b->find('#d', sub {
        my ($el, $e) = @_;
        return do { $terr = $e; EV::break } unless $el;
        $el->text(sub { ($txt, $terr) = @_; EV::break });
    });
    TWK::run_with_timeout(15);
    is($txt, 'hi', 'element handles still work after dedup + sweeping')
        or diag("err=" . ($terr // '(none)'));
    $b->quit;
}

done_testing;
