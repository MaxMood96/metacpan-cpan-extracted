use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# The find/find_all element registry and every internal DOM call run in a
# dedicated JavaScript ISOLATED WORLD -- its own global object and its own
# built-in prototypes, sharing only the DOM with the page. So a hostile (or
# merely buggy) page that pollutes Object.prototype.toJSON AND redefines
# JSON.stringify -- which in the page's own main world corrupts the
# serialization of every object, including the {evwk_id,evwk_epoch}
# descriptor find() marshals back -- cannot reach the isolated world's
# natives. find()/find_all()/wait_for() and the Element accessors therefore
# keep returning CORRECT results regardless of what the page does to its own
# world: the handle points at the right node and the marshalling is clean.
#
# This is the strong guarantee the isolated world buys. (The shape-check in
# find/find_all -- a clean error instead of dereferencing an unexpected
# decoded value -- remains as defence in depth, but the page can no longer
# trigger it through this attack, because the corruption never reaches the
# isolated marshalling in the first place.)
#
# script()/script_async() are the deliberate exception: they run the user's
# JS in the page's MAIN world, so their result IS marshalled by the page's
# (here redefined) JSON.stringify. The guarantee there is only that they
# degrade safely -- a wrong value or a clean marshal error, never a hang.
# Each scenario gets a bounded watchdog so a regression fails loudly/fast.

my $b = EV::WebKit->new(window=>[300,200]);
$b->mock_scheme('mockhostile', sub {
    return ('<html><body>'
          . '<input id="target" value="CORRECT">'
          . '<input id="a" value="AA"><input id="b" value="BB">'
          . '<div id="d">D</div>'
          . '<script>'
          # The full attack: pollute Object.prototype.toJSON so JSON.stringify
          # of ANY object yields an attacker-chosen descriptor (would redirect a
          # handle to registry id 0), AND redefine JSON.stringify itself.
          . 'Object.prototype.toJSON = function () { return { evwk_id: 0, evwk_epoch: "FORGED" }; };'
          . 'JSON.stringify = function () { return "\"PWNED\""; };'
          . '</script></body></html>', 'text/html');
});

my $ready = 0;
$b->go('mockhostile://page', sub {
    my (undef, $err) = @_;
    $ready = 1 unless $err;
    diag("setup: go failed: $err") if $err;
    EV::break;
});
TWK::run_with_timeout(10);
ok($ready, 'setup: hostile page navigated without error') or BAIL_OUT('cannot proceed without the page');

# 1) find() under the attack still resolves to the CORRECT node, and the
#    isolated-world marshalling of its value is clean -- not the forged
#    {evwk_id:0} decoy, not "PWNED", not an error.
{
    my ($el, $err, $fired);
    my $watchdog = EV::timer(8, 0, sub { EV::break });
    $b->find('#target', sub { ($el, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $watchdog;
    ok($fired, 'find: callback fired (did not hang)')
        or diag('find callback never fired');
    ok(!$err, 'find: no error despite Object.prototype.toJSON + JSON.stringify pollution')
        or diag('err=' . ($err // '(undef)'));
    isa_ok($el, 'EV::WebKit::Element', 'find: got a real element handle (not a forged/decoy id)');

  SKIP: {
        skip 'no element', 2 unless $el;
        my ($v, $verr, $vfired);
        my $wd = EV::timer(8, 0, sub { EV::break });
        $el->value(sub { ($v, $verr) = @_; $vfired = 1; EV::break });
        EV::run; undef $wd;
        ok($vfired, 'value: callback fired');
        is($v, 'CORRECT', 'value: correct node, clean isolated-world marshalling (attack defeated)')
            or diag('got=' . (defined $v ? "'$v'" : '(undef)') . ' err=' . ($verr // '(undef)'));
    }
}

# 2) find_all() under the attack: the array itself would also be tampered by
#    the inherited toJSON in the main world -- in the isolated world it comes
#    back intact with the right number of matching nodes.
{
    my ($els, $err, $fired);
    my $watchdog = EV::timer(8, 0, sub { EV::break });
    $b->find_all('input', sub { ($els, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $watchdog;
    ok($fired, 'find_all: callback fired (did not hang)');
    ok(!$err, 'find_all: no error under pollution') or diag('err=' . ($err // '(undef)'));
    is(ref $els, 'ARRAY', 'find_all: got an arrayref');
    is(scalar(@{ $els // [] }), 3, 'find_all: all three <input> nodes (clean array marshalling)');
    isa_ok($els->[0], 'EV::WebKit::Element', 'find_all: first entry is a real element') if $els && @$els;
}

# 3) An Element WRITE atom works on the shared DOM from the isolated world:
#    type() appends, and reading it back yields the correct combined value.
{
    my ($el) = _find1($b, '#target');
    ok($el, 'setup: re-found #target for write test') or BAIL_OUT('need #target');
    my ($ok, $err, $fired);
    my $wd = EV::timer(8, 0, sub { EV::break });
    $el->type('_T', sub { ($ok, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    ok($fired, 'type: callback fired');
    ok(!$err, 'type: no error under pollution') or diag('err=' . ($err // '(undef)'));
    my ($v) = _value1($el);
    is($v, 'CORRECT_T', 'type: mutated the shared DOM node correctly from the isolated world');
}

# 4) wait_for() polls via find() (isolated) -- resolves to the correct node.
{
    my ($el, $err, $fired);
    my $watchdog = EV::timer(8, 0, sub { EV::break });
    $b->wait_for('#d', timeout => 3, sub { ($el, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $watchdog;
    ok($fired, 'wait_for: callback fired');
    ok(!$err, 'wait_for: found the node under pollution (no error)') or diag('err=' . ($err // '(undef)'));
    isa_ok($el, 'EV::WebKit::Element', 'wait_for: correct element');
}

# 5) script() is the documented exception: it runs in the page's MAIN world,
#    so the page's redefined JSON.stringify DOES affect its result. The
#    guarantee is only that it degrades safely -- callback fires (no hang),
#    and any error is clean.
{
    my ($v, $err, $fired);
    my $watchdog = EV::timer(8, 0, sub { EV::break });
    $b->script('return 40 + 2;', sub { ($v, $err) = @_; $fired = 1; EV::break });
    EV::run; undef $watchdog;
    ok($fired, 'script: main-world call still resolves under pollution (no hang)')
        or diag('script callback never fired');
    # It may return a corrupted value or a clean marshal error -- both are
    # acceptable for a main-world call against a page that redefined
    # JSON.stringify; what must never happen is a hang, and any error must be
    # a clean string, not a raw exception object.
    ok(!defined $err || (!ref $err && length $err), 'script: error (if any) is a clean string, not a raw exception')
        or diag('err=' . (ref($err) || $err));
}

$b->quit;
done_testing;

# --- helpers: run a single find()/value() to completion, bounded ------------
sub _find1 {
    my ($br, $sel) = @_;
    my ($el, $fired);
    my $wd = EV::timer(8, 0, sub { EV::break });
    $br->find($sel, sub { ($el) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    return $el;
}
sub _value1 {
    my ($el) = @_;
    my ($v, $fired);
    my $wd = EV::timer(8, 0, sub { EV::break });
    $el->value(sub { ($v) = @_; $fired = 1; EV::break });
    EV::run; undef $wd;
    return $v;
}
