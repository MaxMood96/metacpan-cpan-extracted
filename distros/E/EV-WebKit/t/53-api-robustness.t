use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# API robustness (R17 findings):
#  1. A non-coderef callback used to be accepted and then invoked deep inside
#     an EV/GI completion closure, where the die is swallowed by $EV::DIED and
#     the caller's EV::run hangs forever. Every public async method must now
#     croak synchronously on a defined non-coderef callback (undef is still
#     allowed -- an optional/omitted callback).
#  2. reload() on a browser that never navigated used to stall the full
#     timeout and deliver a misleading 'timeout'; it must degrade at once.
#  3. go(undef) and set_cookie(non-hashref) used to leak raw Perl/GI
#     exceptions; they must deliver the module's clean error style.

my $b = EV::WebKit->new(window => [200, 150]);
$b->mock_scheme('m', sub { ('<html><body><div id=x>X</div></body></html>', 'text/html') });

# ---- 1) non-coderef callback -> synchronous croak, not a swallowed hang ----
my $BAD = 'not_a_coderef';
my @croakers = (
    ['go'            => sub { $b->go('m://x', $BAD) }],
    ['load_html'     => sub { $b->load_html('<p>x</p>', $BAD) }],
    ['back'          => sub { $b->back($BAD) }],
    ['forward'       => sub { $b->forward($BAD) }],
    ['reload'        => sub { $b->reload($BAD) }],
    ['find'          => sub { $b->find('#x', $BAD) }],
    ['find_all'      => sub { $b->find_all('#x', $BAD) }],
    ['script'        => sub { $b->script('return 1', $BAD) }],
    ['script_async'  => sub { $b->script_async('return 1', {}, $BAD) }],
    ['html'          => sub { $b->html($BAD) }],
    ['set_cookie'    => sub { $b->set_cookie({name=>'n',value=>'v',domain=>'d'}, $BAD) }],
    ['cookies'       => sub { $b->cookies('http://x/', $BAD) }],
    ['clear_cookies' => sub { $b->clear_cookies($BAD) }],
    ['save_cookies'  => sub { $b->save_cookies('/tmp/x.json', ['http://x/'], $BAD) }],
    # load_cookies has the same guard in the source but was the one op left out
    # of this sweep -- removing its croak was invisible to the whole suite.
    ['load_cookies'  => sub { $b->load_cookies('/tmp/x.json', $BAD) }],
    # press was the one method that read a mistyped callback as an OPTION NAME
    # -- and warned "Odd number of elements in hash assignment" from inside
    # WebKit.pm on the way. An odd trailing argument is the callback, whatever
    # its type, which is what every other entry here already relies on.
    ['press'         => sub { $b->press('a', $BAD) }],
);
for my $c (@croakers) {
    my ($name, $call) = @$c;
    my $ok = eval { $call->(); 1 };
    ok(!$ok && $@ =~ /callback must be a code reference/,
       "$name: non-coderef callback croaks synchronously (no swallowed hang)")
        or diag("$name did not croak; \$@=" . ($@ // '(none)'));
}

# A defined coderef is of course fine, and an OMITTED callback must NOT croak
# (optional-callback methods). Just check they don't throw synchronously.
ok(eval { $b->back; 1 },  'back() with no callback does not croak');
ok(eval { $b->reload; 1 }, 'reload() with no callback does not croak synchronously');  # may deliver async error; must not throw here

# ---- 2) reload() on a virgin instance resolves at once, not after timeout --
{
    my $vb = EV::WebKit->new(window => [200, 150], timeout => 20);  # long timeout: a regression would ride it out
    my ($v, $err, $fired, $t0);
    my $wd = EV::timer(6, 0, sub { EV::break });   # a regression (timeout-only) would blow past this
    $t0 = EV::time;
    $vb->reload(sub { ($v, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    my $took = EV::time - $t0;
    ok($fired, 'reload(virgin): callback fired promptly (not a full-timeout stall)');
    like($err // '', qr/nothing to reload/, 'reload(virgin): clean immediate error');
    ok($took < 5, sprintf('reload(virgin): resolved in %.2fs, well under the 20s timeout', $took));
    $vb->quit;
}

# ---- 3) clean errors for malformed args (no raw exception) -----------------
{
    my ($v, $err, $fired);
    my $wd = EV::timer(6, 0, sub { EV::break });
    $b->go(undef, sub { ($v, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    ok($fired, 'go(undef): callback fired');
    like($err // '', qr/uri required/, 'go(undef): clean "uri required" (not a raw GI die)');
}
{
    my ($v, $err, $fired);
    my $wd = EV::timer(6, 0, sub { EV::break });
    $b->set_cookie('not_a_hashref', sub { ($v, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    ok($fired, 'set_cookie(string): callback fired');
    like($err // '', qr/hash reference/, 'set_cookie(string): clean "hash reference" error (not a raw HASH-deref die)');
}

# The same guard must hold on an Element handle. Its 13 accessors all route
# through one shim, and find/find_all pass their OWN closure down to it -- so
# the browser's guards never see the caller's callback, and a non-coderef used
# to blow up deep inside the completion, where $EV::DIED eats the die and the
# caller's EV::run just hangs.
{
    my $el;
    $b->load_html('<html><body><div id="e">x</div></body></html>', sub {
        $b->find('#e', sub { $el = shift; EV::break });
    });
    TWK::run_with_timeout(15);
    ok($el, 'setup: got an element handle') or BAIL_OUT('no element');

    my @m = (
        ['text'     => sub { $el->text($BAD) }],
        ['html'     => sub { $el->html($BAD) }],
        ['value'    => sub { $el->value($BAD) }],
        ['tag'      => sub { $el->tag($BAD) }],
        ['attr'     => sub { $el->attr('id', $BAD) }],
        ['prop'     => sub { $el->prop('id', $BAD) }],
        ['is_visible'=> sub { $el->is_visible($BAD) }],
        ['click'    => sub { $el->click($BAD) }],
        ['focus'    => sub { $el->focus($BAD) }],
        ['type'     => sub { $el->type('hi', $BAD) }],
        ['clear'    => sub { $el->clear($BAD) }],
        ['submit'   => sub { $el->submit($BAD) }],
        ['find'     => sub { $el->find('#x', $BAD) }],
        ['find_all' => sub { $el->find_all('#x', $BAD) }],
        # uncheck takes NO state, so a trailing non-coderef there can only be a
        # mistyped callback -- it used to be swallowed and nothing ever answered.
        # check is deliberately absent: its first argument IS a state, so a bare
        # string there is a legitimate (truthy) value, not a mistake.
        ['uncheck'  => sub { $el->uncheck($BAD) }],
        ['hover'    => sub { $el->hover($BAD) }],
        ['box'      => sub { $el->box($BAD) }],
        ['scroll_into_view' => sub { $el->scroll_into_view($BAD) }],
        ['select_option'    => sub { $el->select_option('x', $BAD) }],
    );
    for my $m (@m) {
        my ($name, $call) = @$m;
        my $threw = !eval { $call->(); 1 };
        ok($threw, "Element::$name croaks synchronously on a non-coderef callback")
            or diag("did not croak -- the die would land in \$EV::DIED and hang the caller's EV::run");
    }
}

$b->quit;

# The constructor must reject unknown options rather than silently ignore them:
# a typo'd proxy => would route DIRECT (deanonymization) and a typo'd data_dir =>
# would silently fall back to an ephemeral (non-persistent) session. A valid
# option set must still construct (guards against an incomplete known-key list).
{
    eval { EV::WebKit->new(window=>[100,80], proxxy=>'http://127.0.0.1:1') };
    like($@, qr/unknown option.*proxxy/, "new() croaks on a typo'd option (proxxy)");
    eval { EV::WebKit->new(window=>[100,80], data_directory=>'/tmp/x') };
    like($@, qr/unknown option.*data_directory/, "new() croaks on a typo'd data_dir");
    my $ok = EV::WebKit->new(window=>[100,80], ephemeral=>1, timeout=>5, chrome=>0);
    isa_ok($ok, 'EV::WebKit', 'new() still accepts a valid option set');
    $ok->quit;
}

# check() takes at most a state and a callback, and the guard that says so had
# no coverage: removed, check(1, 'not_a_coderef') did not croak and then never
# answered -- the swallowed-hang mode this whole file exists to prevent. Over
# the wire the arity ceiling catches it first, so this is the only reach.
{
    # a fresh browser: $b was quit above
    my $cb2 = EV::WebKit->new(window => [200, 150], ephemeral => 1, timeout => 10);
    my $el;
    $cb2->load_html('<html><body><input id=c type=checkbox></body></html>', sub {
        $cb2->find('#c', sub { $el = shift; EV::break });
    });
    TWK::run_with_timeout(15);
    ok($el, 'setup: got a checkbox handle');
  SKIP: {
        skip 'no handle', 4 unless $el;
        ok(!eval { $el->check(1, $BAD); 1 }, 'check(state, non-coderef) croaks');
        like($@, qr/at most a state and a callback/, '...saying what it takes');
        # the shapes that must still work
        ok(eval { $el->check(sub { EV::break }); 1 }, 'check(cb) is accepted') or diag $@;
        TWK::run_with_timeout(10);
        ok(eval { $el->check(0, sub { EV::break }); 1 }, 'check(state, cb) is accepted') or diag $@;
        TWK::run_with_timeout(10);
    }
    $cb2->quit;
}

# Synchronous validation where the module already validates synchronously
# elsewhere: new() croaks a non-coderef on_* rather than letting it surface at
# fire time, and an odd option list is a dropped token -- for add_user_script
# that means silently falling back to a MORE PERMISSIVE default (main world, no
# allow/deny), which is the wrong direction for an injection API.
{
    my $v = EV::WebKit->new(window => [100,80], ephemeral => 1, timeout => 5);
    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };

    ok(!eval { $v->mock_scheme('zz', 'not a coderef'); 1 },
       'mock_scheme croaks on a non-coderef producer');
    like($@, qr/producer must be a code reference/, '...saying so');
    # undef alone does NOT pin this: Glib::Object::Introspection raises its own
    # "undefined value for mandatory argument" for that one, so the assertion
    # passes with the guard deleted. The empty string and a ref are the shapes
    # that need it -- unguarded, both are accepted and the scheme is silently
    # never registered (only a C-level "Cannot register invalid URI scheme").
    ok(!eval { $v->mock_scheme(undef, sub {}); 1 }, 'mock_scheme croaks on a missing scheme name');
    ok(!eval { $v->mock_scheme('', sub {}); 1 }, 'mock_scheme croaks on an empty scheme name');
    like($@, qr/scheme name is required/, '...from our guard, not from GI');
    ok(!eval { $v->mock_scheme([], sub {}); 1 }, 'mock_scheme croaks on a ref scheme name');
    like($@, qr/scheme name is required/, '...from our guard too');

    ok(!eval { $v->add_user_script('x', 'world'); 1 },
       'add_user_script croaks on an odd option list');
    like($@, qr/name => value pairs/, '...rather than dropping the token and defaulting the world');
    ok(!eval { $v->add_user_style('x', 'level'); 1 }, 'add_user_style croaks on an odd option list');

    ok(!eval { EV::WebKit->new(window => [100,80], 'ephemeral'); 1 },
       'new() croaks on an odd option list');
    like($@, qr/name => value pairs/, '...saying so');

    is(scalar(@w), 0, 'none of that warned from inside the module');
    ok(eval { $v->mock_scheme('zz', sub { ('<p>ok</p>', 'text/html') }); 1 },
       'a well-formed mock_scheme is still accepted') or diag $@;
    $v->quit;
}

done_testing;
