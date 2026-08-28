use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# Robustness of the event/config surface (R18 findings):
#  1 on_dialog that throws must not wedge the WebView.
#  2 settings() must reject a reference value (else GI numifies its address).
#  3 find()/find_all() with an omitted callback must not die in the completion.
#  4 set_user_agent() must reject a UA WebKit would silently drop.
#  5 a nav failure with no per-call callback must reach on_error.
#  6 a throwing per-call nav callback must not rob on_load of its turn.

# ---- 1) throwing on_dialog does not wedge the view ------------------------
{
    my @warns; local $SIG{__WARN__} = sub { push @warns, $_[0] };
    my $b = EV::WebKit->new(window => [200,150], timeout => 8, on_dialog => sub { die "boom\n" });
    $b->mock_scheme('dlg', sub { ('<html><body><script>confirm("q?");document.title="after";</script></body></html>','text/html') });
    my ($done, $err);
    my $wd = EV::timer(12, 0, sub { EV::break });
    $b->go('dlg://p', sub { (undef, $err) = @_; $done = 1; EV::break });
    EV::run; undef $wd;
    ok($done, 'dialog: a throwing on_dialog still lets the confirm()-page nav resolve (not wedged)');

    my ($v, $vfired);
    my $wd2 = EV::timer(8, 0, sub { EV::break });
    $b->script('return 1+1', sub { ($v) = @_; $vfired = 1; EV::break });
    EV::run; undef $wd2;
    ok($vfired && ($v // 0) == 2, 'dialog: a later script() still resolves after a throwing dialog (view not wedged)');
    ok((grep { /on_dialog callback died/ } @warns), 'dialog: the handler exception was surfaced as a warning');
    $b->quit;
}

# ---- 2) settings() rejects a reference value ------------------------------
{
    my $b = EV::WebKit->new(window => [200,150]);
    my $ok = eval { $b->settings({ default_font_size => {} }); 1 };
    ok(!$ok && $@ =~ /must be a scalar/, 'settings: a reference value croaks (not silently coerced to garbage)')
        or diag("got: " . ($@ // '(no error)'));
    # a valid scalar still applies
    ok(eval { $b->settings({ default_font_size => 20 }); 1 }, 'settings: a valid scalar value still applies');
    is($b->{view}->get_settings->get('default-font-size'), 20, 'settings: the scalar value took effect');
    $b->quit;
}

# ---- 3) find()/find_all() with no callback do not die in the completion ---
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('f', sub { ('<html><body><div id=x>X</div><div class=y>Y</div></body></html>','text/html') });
    my $loaded;
    my $wd = EV::timer(10, 0, sub { EV::break });
    $b->go('f://p', sub { $loaded = 1; EV::break });
    EV::run; undef $wd;
    ok($loaded, 'setup loaded');

    my $died;
    local $EV::DIED = sub { $died = $@ };
    $b->find('#x');          # NO callback
    $b->find_all('.y');      # NO callback
    my $wd2 = EV::timer(5, 0, sub { EV::break });
    EV::run; undef $wd2;     # let both completions run
    ok(!$died, 'find()/find_all() with an omitted callback complete without dying')
        or diag("EV::DIED saw: $died");
    $b->quit;
}

# ---- 4) set_user_agent() rejects any UA WebKit would silently drop --------
# Verified by read-back (not a charset guess), so it catches WebKit's whole
# reject set: control chars, bytes >= 0x80, leading/trailing whitespace, and
# embedded quote/backslash.
{
    my $b = EV::WebKit->new(window => [200,150]);
    ok(eval { $b->set_user_agent('MonBot/1.0'); 1 }, 'set_user_agent: a normal UA applies');
    is($b->user_agent, 'MonBot/1.0', 'set_user_agent: the ASCII UA took effect');
    # a realistic UA with internal spaces, parens, slashes, dots, semicolons applies
    my $real = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/605.1 (KHTML, like Gecko)';
    ok(eval { $b->set_user_agent($real); 1 }, 'set_user_agent: a realistic browser UA applies');
    is($b->user_agent, $real, 'set_user_agent: the realistic UA round-trips');

    my $good = $b->user_agent;   # the last known-good value
    for my $bad (
        ["emoji (>U+00FF)"        => "MonBot/1.0 (\x{1F600})"],
        ["Latin-1 0xE9"           => "caf\x{e9}Bot/1.0"],
        ["leading space"          => " MonBot/1.0"],
        ["trailing space"         => "MonBot/1.0 "],
        ["embedded double-quote"  => 'bad"ua/1.0'],
        ["embedded backslash"     => 'bad\\ua/1.0'],
        ["control char"           => "Mon\x02Bot/1.0"],
    ) {
        my ($label, $ua) = @$bad;
        my $ok = eval { $b->set_user_agent($ua); 1 };
        ok(!$ok && $@ =~ /rejected|unsupported/i, "set_user_agent: rejects $label (croaks, not a silent no-op)")
            or diag("$label: got " . ($@ // '(no error)'));
        is($b->user_agent, $good, "set_user_agent: $label left the previous UA intact");
    }
    $b->quit;
}

# ---- 4b) the constructor user_agent option is validated too ---------------
{
    # a valid constructor UA applies and round-trips
    my $b = EV::WebKit->new(window => [200,150], user_agent => 'CtorBot/1.0');
    is($b->user_agent, 'CtorBot/1.0', 'new(user_agent=>): a valid UA applies at construction');
    $b->quit;
    # a bad constructor UA must not silently no-op -- new() croaks
    my $ok = eval { EV::WebKit->new(window => [200,150], user_agent => 'bad"ua/1.0') };
    ok(!$ok && $@ =~ /rejected|unsupported/i, 'new(user_agent=>): a bad UA croaks (not silently dropped)')
        or diag("got: " . ($@ // '(no error)'));
}

# ---- 5) a nav failure with no per-call callback reaches on_error ----------
{
    my @errs;
    my $b = EV::WebKit->new(window => [200,150], timeout => 8,
                            on_error => sub { push @errs, $_[0]; EV::break });
    $b->mock_scheme('failme', sub { die "producer boom\n" });   # producer die -> clean nav failure
    my $wd = EV::timer(12, 0, sub { EV::break });
    $b->go('failme://x');    # NO per-call callback
    EV::run; undef $wd;
    ok(@errs == 1, 'on_error: a callback-less nav failure fires on_error exactly once')
        or diag("on_error fired " . scalar(@errs) . " times");
    ok(defined $errs[0], 'on_error: received an error string') if @errs;
    $b->quit;
}

# ---- 6) a throwing per-call nav callback still lets on_load fire ----------
{
    my $on_load = 0;
    my $died;
    local $EV::DIED = sub { $died = $@; EV::break };   # the cb's re-surfaced exception lands here
    my $b = EV::WebKit->new(window => [200,150],
                            on_load => sub { $on_load++ });
    $b->mock_scheme('ok', sub { ('<html><body>hi</body></html>','text/html') });
    my $wd = EV::timer(10, 0, sub { EV::break });
    $b->go('ok://p', sub { die "cb boom\n" });   # success callback throws
    EV::run; undef $wd;
    is($on_load, 1, 'on_load: still fires even though the per-call callback threw');
    ok(defined $died && $died =~ /cb boom/, 'on_load: the callback exception is still surfaced (via EV::DIED)')
        or diag("EV::DIED saw: " . ($died // '(nothing)'));
    $b->quit;
}

# ---- 7) superseding a callback-less nav must NOT fire on_error ------------
# on_error is for genuine failures with no callback waiting; 'superseded' is
# the instance's own intentional navigate-away, not a failure.
{
    my @errs;
    my $b = EV::WebKit->new(window => [200,150], timeout => 8,
                            on_error => sub { push @errs, $_[0] });
    $b->mock_scheme('sup', sub { ('<html><body>hi</body></html>','text/html') });
    my ($done);
    my $wd = EV::timer(12, 0, sub { EV::break });
    $b->go('sup://one');                                   # callback-less, fire-and-forget
    $b->go('sup://two', sub { $done = 1; EV::break });     # supersedes 'one'
    EV::run; undef $wd;
    ok($done, 'supersede: the second nav resolved');
    is(scalar(@errs), 0, "supersede: a callback-less navigate-away does NOT fire on_error")
        or diag("on_error saw: [@errs]");
    $b->quit;
}

# ---- 7b) but a callback ON the superseded nav still gets 'superseded' -----
{
    my @errs;
    my ($se, $done);
    my $b = EV::WebKit->new(window => [200,150], timeout => 8,
                            on_error => sub { push @errs, $_[0] });
    $b->mock_scheme('sup2', sub { ('<html><body>hi</body></html>','text/html') });
    my $wd = EV::timer(12, 0, sub { EV::break });
    $b->go('sup2://one', sub { $se = $_[1] });             # WITH a callback
    $b->go('sup2://two', sub { $done = 1; EV::break });    # supersedes it
    EV::run; undef $wd;
    is($se, 'superseded', 'supersede: a callback on the superseded nav still receives it');
    is(scalar(@errs), 0, 'supersede: on_error still silent when the superseded nav had its own callback');
    $b->quit;
}

done_testing;
