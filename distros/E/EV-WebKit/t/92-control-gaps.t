use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available(); use TCTL;
use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Client; use EV::WebKit::Protocol;

# Gaps mutation testing found: guards that are load-bearing but were unproven,
# and paths no test drove. Each of these is a mutant that survived a green suite.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/g.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('g', sub { ('<html><body><h1>hi</h1></body></html>', 'text/html') });
my $ctl = EV::WebKit::Control->listen($b, path => $path);

# 1) A SYNC method that CROAKS over the wire must still be answered. settings
#    with a non-hashref, set_user_agent with a ref -- these die inside the
#    browser, and an unanswered request is a hung client, the one failure mode
#    this protocol must not have.
#
#    Two evals stand between that croak and silence: the one around the sync
#    dispatch itself, and the per-frame one in _read. This pins the OUTCOME, not
#    either mechanism -- removing just one of them still passes, because the
#    other catches the croak and answers with the same cleaned message. Both
#    would have to go for this to fail.
{
    my $cl = TCTL->new($path); $cl->pump(1);
    my $r = $cl->reply({ i => 1, m => 'settings', a => ['not a hashref'] });
    ok($r && defined $r->{e}, 'a sync method that croaks is answered with an error, not silence')
        or diag('no answer -- the client would hang');
    # and the connection still works afterwards
    is($cl->reply({ i => 2, m => 'title' })->{i}, 2, '...and the connection survives it');
    $cl->close;
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 2) A sync request answered EXACTLY once -- no stray second frame for one id.
{
    my $cl = TCTL->new($path); $cl->pump(1);
    $cl->send_frame({ i => 5, m => 'title' });
    my @f = $cl->pump(3, 5);       # pump a bit longer than one answer
    my @ans = grep { !defined $_->{ev} && ($_->{i} // 0) == 5 } @f;
    is(scalar @ans, 1, 'a request is answered exactly once (no double-fire)');
    $cl->close;
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# A browser method called with the wrong number of positional arguments must be
# answered, not left to hang. The generic dispatch appends the answer-callback
# to whatever the client sent, so a wrong count moves it out of its slot: the
# real callback slot is then undef, every error path is `return unless $cb`, and
# nothing is ever sent back -- a blocking client waits in sysread forever, an ev
# one's callback never fires. Too FEW is worse still for go/load_html, which
# navigate the browser to the stringified coderef; too MANY is reached by a
# single trailing JSON null, the "no callback" a user writes when porting a
# local script, which the methods' own `if defined $cb && ref $cb ne 'CODE'`
# guard cannot catch because undef is not defined. The el.* methods have had
# both bounds from the start; this is the same pair on the other half of the
# mirror.
{
    my $cl = TCTL->new($path); $cl->pump(1);
    my $i = 500;
    # Too FEW. Everything with a minimum above zero.
    my @floored = qw(go load_html script script_async set_cookie cookies
                     load_cookies save_cookies wait_for_js press pdf);
    # These two are answered earlier still, by their own validation, which says
    # something more specific. What matters is the same for all of them: an
    # answer, never silence.
    my @already  = qw(find wait_for);
    for my $m (@floored, @already) {
        my $r = $cl->reply({ i => $i++, m => $m, a => [] }, 6);
        ok($r && defined $r->{e}, "$m with no arguments is answered with an error, not silence")
            or diag('no answer -- the client would hang here');
        like(($r && $r->{e}) // '', qr/expected .*argument.*got 0\b/,
             "...and $m is caught by the arity floor")
            if grep { $_ eq $m } @floored;
    }
    # the two-argument floor, whose plural the one-argument cases never exercise
    for my $m (qw(download resize)) {
        my $r2 = $cl->reply({ i => $i++, m => $m, a => ['only-one'] }, 6);
        like(($r2 && $r2->{e}) // '', qr/expected 2 arguments/,
             "$m with one argument is caught by the floor, plural and all");
    }

    # Too MANY: one trailing null past each bounded method's maximum. Fourteen
    # of these sixteen hung before the ceiling existed. The other two got away
    # with it for their own reasons -- frames croaks (its guard is a bare
    # `ref $cb ne 'CODE'`, with no `defined` in front of it) and save_cookies
    # pops its callback -- which is precisely why the ceiling is a table and not
    # a rule inferred per method.
    my %over = (
        go            => ['about:blank', undef],
        load_html     => ['<b>x</b>', undef],
        script        => ['return 1;', undef],
        script_async  => ['return 1;', {}, undef],
        back          => [undef],
        forward       => [undef],
        reload        => [undef],
        html          => [undef],
        frames        => [undef],
        clear_cookies => [undef],
        resize        => [800, 600, undef],
        download      => ['about:blank', "$dir/dl", undef],
        set_cookie    => [{ name => 'a', value => 'b', domain => 'x' }, undef],
        cookies       => ['http://x/', undef],
        load_cookies  => ["$dir/nope.txt", undef],
        save_cookies  => ["$dir/nope.txt", [], undef],
    );
    for my $m (sort keys %over) {
        my $r = $cl->reply({ i => $i++, m => $m, a => $over{$m} }, 6);
        ok($r && defined $r->{e}, "$m with a trailing null is answered, not silence")
            or diag('no answer -- the client would hang here');
        like(($r && $r->{e}) // '', qr/expected .*argument/,
             "...and $m is caught by the arity ceiling");
    }

    # Each distinct shape of the message, exactly. Without these the plural is
    # half-unasserted: every regex above matches both spellings, so `argument`
    # hardcoded to `arguments` (or the reverse) survives a green suite.
    my @shape = (
        [ 'reload',       [undef],                   'reload: expected 0 arguments, got 1'         ],
        [ 'go',           [],                        'go: expected 1 argument, got 0'              ],
        [ 'resize',       [1],                       'resize: expected 2 arguments, got 1'         ],
        [ 'script_async', [],                        'script_async: expected 1 to 2 arguments, got 0' ],
        [ 'press',        [],                        'press: expected at least 1 argument, got 0'  ],
    );
    for my $s (@shape) {
        my ($m, $a, $want) = @$s;
        my $r = $cl->reply({ i => $i++, m => $m, a => $a }, 6);
        is(($r && $r->{e}) // '', $want, "$m: the message says exactly '$want'");
    }

    # The methods that take trailing key/value OPTIONS cannot have a ceiling --
    # the client chooses how many pairs to send, and they ride in `a`. What is
    # left to assert is the invariant itself: a trailing null must still produce
    # an answer, whatever it says.
    #
    # It does NOT pin WHY they are safe. Each pops its callback off the end
    # rather than binding it positionally, but rewriting one to bind
    # positionally still passes here -- the junk option it then builds croaks,
    # and the dispatch eval turns that croak into an answer. Measured, all four.
    # The invariant is what matters and the invariant is what is checked.
    my %popped = (
        press               => ['x', undef],
        wait_for_js         => ['1', undef],
        pdf                 => ["$dir/a.pdf", undef],
        wait_for_navigation => [undef],
    );
    for my $m (sort keys %popped) {
        my $r = $cl->reply({ i => $i++, m => $m, a => $popped{$m} }, 15);
        ok($r, "$m answers a trailing null rather than going silent")
            or diag('no answer -- the client would hang here');
    }

    # ...and none of it took the browser down. (Liveness only: with the floor
    # removed the browser IS measurably touched -- the stringified coderef
    # reaches load_uri and uri goes from undef to '' -- which is what the
    # per-method assertions above are for.)
    my $t = $cl->reply({ i => $i++, m => 'title' }, 10);
    ok($t && !exists $t->{e}, 'the browser is still answering afterwards');

    # script_async binds positionally ($body, \%args, $cb), so the natural
    # one-argument spelling -- like its script() sibling -- has to work rather
    # than land the callback in the args slot.
    my $r = $cl->reply({ i => $i++, m => 'script_async', a => ['return 6 * 7;'] }, 15);
    ok($r && !exists $r->{e}, 'script_async with just a body is accepted')
        or diag(($r && $r->{e}) // 'no answer');
    is($r && $r->{r}, 42, '...and runs it');
    $cl->close;
    for (1 .. 3) { my $t2 = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# The OTHER half of the mirror: el.* has carried a [min, max] guard from the
# start -- it is the guard %ARITY above was modelled on -- and nothing in the
# suite pinned it. Removing it leaves every control test green while thirteen
# element methods hang on a:[null], because the twelve [0,0] methods and uncheck
# all reach `_call_js(..., $_[1])`, whose guard is `if defined $cb && ref $cb ne
# 'CODE'` and so cannot see an undef. (A trailing STRING croaks cleanly; it is
# specifically the JSON null that goes silent.)
{
    my $cl = TCTL->new($path); $cl->pump(1);
    my $i = 800;
    $cl->reply({ i => $i++, m => 'go', a => ['g://x'] }, 25);
    my $fr = $cl->reply({ i => $i++, m => 'find', a => ['h1'] }, 25);
    my $h  = $fr && $fr->{r} && $fr->{r}{h};
    ok(defined $h, 'premise: a handle to work with') or diag(($fr && $fr->{e}) // 'no answer');

  SKIP: {
        skip 'no handle', 50 unless defined $h;   # 21 x 2 ceilings + 7 floors + 1
        # every entry in %EL_METHOD, at max + 1
        my @none = qw(text html value tag is_visible click focus clear submit
                      scroll_into_view hover box uncheck);
        my @one  = qw(attr prop type find find_all select_option send_keys);
        my %over = ( (map { $_ => [undef] } @none),
                     check => [1, undef],
                     (map { $_ => ['x', undef] } @one) );
        for my $m (sort keys %over) {
            my $r = $cl->reply({ i => $i++, m => "el.$m", h => $h, a => $over{$m} }, 6);
            ok($r && defined $r->{e}, "el.$m with a trailing null is answered, not silence")
                or diag('no answer -- the client would hang here');
            like(($r && $r->{e}) // '', qr/expected .*argument/,
                 "...and el.$m is caught by the arity ceiling");
        }
        # and the floor, for the seven that require an argument
        for my $m (@one) {
            my $r = $cl->reply({ i => $i++, m => "el.$m", h => $h, a => [] }, 6);
            like(($r && $r->{e}) // '', qr/expected .*argument/,
                 "el.$m with no arguments is caught by the arity floor");
        }
        # the handle still works afterwards
        my $ok = $cl->reply({ i => $i++, m => 'el.tag', h => $h }, 10);
        ok($ok && !exists $ok->{e}, 'the handle is still usable after all of that')
            or diag(($ok && $ok->{e}) // 'no answer');
    }
    $cl->close;
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 3) listen(): a STALE socket file is reused; a LIVE one is refused. Neither
#    branch was exercised anywhere.
{
    my $sp = "$dir/stale.sock";
    # a plain leftover file where the socket should be
    open my $f, '>', $sp or die $!; close $f;
    my $tb = EV::WebKit->new(window => [200,150], ephemeral => 1);
    my $t_ctl = eval { EV::WebKit::Control->listen($tb, path => $sp) };
    ok($t_ctl, 'listen() reuses a stale socket path (a leftover file is cleared)')
        or diag("refused a stale path: $@");

    # a second listen on the SAME live path must be refused, not silently steal it
    my $tb2 = EV::WebKit->new(window => [200,150], ephemeral => 1);
    my $ok = eval { EV::WebKit::Control->listen($tb2, path => $sp); 1 };
    ok(!$ok, 'listen() refuses a path already served by a live process');
    like($@, qr/already served/, '...saying why');
    $t_ctl->close if $t_ctl;
    $tb->quit; $tb2->quit;
}

# 4) ev mode: TWO requests genuinely in flight at once, each matched by its own
#    id -- not by arrival order. A slow op issued before a fast one answers
#    second, and the wrong-order match would silently hand each caller the
#    other's result.
{
    my $c = EV::WebKit::Client->connect($path, ev => 1);
    my (%got, $pending);
    $pending = 2;
    # a slow script (a real delay) issued FIRST, a fast one SECOND
    $c->script('return await new Promise(r => setTimeout(() => r("SLOW"), 400))', sub { $got{slow} = $_[0]; EV::break unless --$pending });
    $c->script('return "FAST"', sub { $got{fast} = $_[0]; EV::break unless --$pending });
    my $wd = EV::timer(20, 0, sub { EV::break }); EV::run; undef $wd;
    is($got{slow}, 'SLOW', 'ev mode: the slow request gets the slow result...');
    is($got{fast}, 'FAST', '...and the fast one gets the fast result (matched by id, not arrival order)');
    $c->disconnect;
}

# 5) ev mode: the browser dies with a request still in flight. Every pending
#    callback must be answered with an error, not dropped -- a dropped callback
#    is a hung caller.
{
    my $tdir = tempdir(CLEANUP => 1);
    my $tpath = "$tdir/die.sock";
    my $tb = EV::WebKit->new(window => [200,150], ephemeral => 1);
    $tb->mock_scheme('d', sub { ('<html><body>x</body></html>', 'text/html') });
    my $tctl = EV::WebKit::Control->listen($tb, path => $tpath);

    my $c = EV::WebKit::Client->connect($tpath, ev => 1);
    my ($fired, $err) = (0, undef);
    # a slow request, so it is genuinely still in flight when we kill the server
    $c->script('return await new Promise(r => setTimeout(() => r(1), 5000))', sub { $fired++; $err = $_[1]; EV::break });
    # tear the server + browser down while it is outstanding
    my $kill = EV::timer(0.3, 0, sub { $tctl->close; $tb->quit });
    my $wd   = EV::timer(15, 0, sub { EV::break }); EV::run; undef $wd; undef $kill;
    is($fired, 1, 'ev mode: a request in flight when the browser dies IS answered');
    ok(defined $err, '...with an error, not dropped') or diag('the callback never fired -- a hung caller');
    $c->disconnect;
}

# 6) Control chains EVERY handler, not just on_console. A browser built with its
#    own on_load/on_error must keep firing them after Control wires its events on
#    top.
{
    my $tdir = tempdir(CLEANUP => 1);
    my $tpath = "$tdir/chain.sock";
    my @own_load;
    my $tb = EV::WebKit->new(window => [200,150], ephemeral => 1,
                             on_load => sub { push @own_load, 'own' });
    $tb->mock_scheme('c', sub { ('<html><body>x</body></html>', 'text/html') });
    my $tctl = EV::WebKit::Control->listen($tb, path => $tpath);   # wires on_load on top

    my $cl = TCTL->new($tpath); $cl->pump(1);
    $cl->reply({ i => 1, m => 'go', a => ['c://p'] }, 20);
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    ok(scalar(@own_load) >= 1,
        "the browser's own on_load still fires after Control chains onto it (not clobbered)")
        or diag('Control replaced the handler instead of chaining it');
    $cl->close; $tctl->close; $tb->quit;
}

# 7) A cookie set through the protocol survives a disconnect + reconnect. This is
#    the design's use case 2 (reuse a logged-in session), and nothing tested it
#    through the wire -- the shipped re-attach test only checked uri/title.
#
#    Driven with TCTL (a raw socket that pumps the loop itself), NOT a blocking
#    EV::WebKit::Client: a blocking client in THIS process would sit in sysread
#    and never let the browser's own loop run to answer it -- a deadlock, which
#    is exactly why the real blocking-client tests run in a child (see t/88).
{
    my $tdir = tempdir(CLEANUP => 1);
    my $tpath = "$tdir/cookie.sock";
    my $tb = EV::WebKit->new(window => [200,150], ephemeral => 1);
    my $tctl = EV::WebKit::Control->listen($tb, path => $tpath);

    my $c1 = TCTL->new($tpath); $c1->pump(1);       # hello
    $c1->reply({ i => 1, m => 'set_cookie',
                 a => [{ name => 'sid', value => '42', domain => 'example.com', path => '/' }] }, 15);
    $c1->close;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }   # let the server reap it

    my $c2 = TCTL->new($tpath); $c2->pump(1);       # a fresh connection, same browser
    my $r = $c2->reply({ i => 1, m => 'cookies', a => ['http://example.com/'] }, 15);
    my $list = $r->{r} || [];
    ok(scalar(grep { $_->{name} eq 'sid' && $_->{value} eq '42' } @$list),
        'a cookie set through the protocol survives a client disconnect + reconnect (session reuse)')
        or diag('the cookie did not survive -- use case 2 is broken over the wire');
    $c2->close;
    $tctl->close; $tb->quit;
}

$ctl->close;
$b->quit;
done_testing;
