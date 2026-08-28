use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;
use Time::HiRes ();

# wait_for(gone => 1) and wait_for_js.
#
# Both run on the same polling engine as wait_for -- extracted rather than
# copied, so the weak-alias / waiter-registry / single-resolution-point
# invariants have exactly one home. t/43, t/44, t/50 and friends still cover
# that engine through wait_for itself.
#
# One instance, one EV::run, queued steps (t/42's constraint).

my $b = EV::WebKit->new(window => [300, 200], timeout => 10);
my %g;
my @steps;
my $run; $run = sub { my $s = shift @steps or return EV::break; $s->() };

my $fixture = <<'HTML';
<div id=spinner>loading</div>
<script>
  window.appReady = false;
  setTimeout(() => { document.getElementById('spinner').remove(); }, 150);
  setTimeout(() => { window.appReady = true; }, 200);
  setTimeout(() => { window.late = { ready: true }; }, 250);
</script>
HTML

# --- gone: waits for the selector to match nothing ---
push @steps, sub {
    my $t0 = time;
    $b->wait_for('#spinner', gone => 1, sub {
        my ($ok, $err) = @_;
        $g{gone_ok}  = $ok;
        $g{gone_err} = $err;
        $g{gone_took} = time - $t0;
        $run->();
    });
};

# ...and returns immediately when it already matches nothing
push @steps, sub {
    $b->wait_for('#never-existed', gone => 1, sub {
        ($g{absent_ok}, $g{absent_err}) = @_;
        $run->();
    });
};

# ...and times out when the element STAYS
push @steps, sub {
    $b->wait_for('body', gone => 1, timeout => 0.3, sub {
        ($g{stays_ok}, $g{stays_err}) = @_;
        $run->();
    });
};

# --- wait_for_js: a predicate that becomes true ---
push @steps, sub {
    $b->wait_for_js('window.appReady', sub {
        ($g{js_val}, $g{js_err}) = @_;
        $run->();
    });
};

# A predicate that THROWS until it does not: `window.late.ready` is a TypeError
# for as long as window.late is undefined. This is the case that makes
# retry-on-throw mandatory -- failing on it would make the common shape unusable.
#
# The scheduling is deliberate and load-bearing. An earlier version armed this
# in the page fixture, and by the time the queued steps reached it the timer had
# long since fired, so the predicate NEVER threw and the assertion passed
# vacuously -- proven by mutation: making a throw terminal did not fail it.
# Arming it here, immediately before the wait, guarantees the throwing window.
push @steps, sub {
    $b->script('delete window.late; setTimeout(() => { window.late = { ready: true } }, 200); return 1;', sub {
        # confirm it really is throwing right now, so the assertion below cannot
        # go vacuous again without this failing first
        $b->script('try { return window.late.ready === undefined ? "no-throw" : "no-throw" } catch (e) { return "throws" }', sub {
            $g{throw_state} = $_[0];
            $b->wait_for_js('window.late.ready', sub {
                ($g{throw_val}, $g{throw_err}) = @_;
                $run->();
            });
        });
    });
};

# a predicate that never comes true: times out, and the message names the
# expression rather than saying a bare 'timeout'
push @steps, sub {
    $b->wait_for_js('window.nope === 42', timeout => 0.3, sub {
        ($g{never_val}, $g{never_err}) = @_;
        $run->();
    });
};

# a predicate that always throws: also times out, but the message carries the
# last JS error -- otherwise a typo is indistinguishable from "not yet"
push @steps, sub {
    $b->wait_for_js('no_such_function()', timeout => 0.3, sub {
        ($g{bad_val}, $g{bad_err}) = @_;
        $run->();
    });
};

# JS truthiness, not Perl truthiness.
#
# The predicate's verdict is reached in JavaScript and sent back beside the
# value. Deciding it in Perl instead -- on whatever came back through
# JSON.stringify -- silently inverted the two cases that matter most:
#
#   * a FUNCTION has no JSON form, so it arrived as undef and read as false.
#     wait_for_js('window.jQuery') -- the canonical "has the library loaded"
#     check, and the first thing anyone reaches for -- timed out every time,
#     on a value that was truthy before the wait even started.
#   * the string "0" is true in JavaScript and false in Perl.
#
# Both are asserted here against values that are true from the first poll, so a
# regression is a timeout rather than a slow pass.
push @steps, sub {
    $b->script('window.libFn = function () { return 1 }; window.zeroStr = "0"; return 1;', sub {
        $b->wait_for_js('window.libFn', timeout => 2, sub {
            ($g{fn_val}, $g{fn_err}) = @_;
            $b->wait_for_js('window.zeroStr', timeout => 2, sub {
                ($g{zero_val}, $g{zero_err}) = @_;
                $run->();
            });
        });
    });
};

# The timeout is in SECONDS, and it means it.
#
# It used to be counted in POLLS -- $elapsed += $interval once per completed
# probe -- which ignored the probe's own round trip, and every probe here is a
# full JS round trip. Two ways that goes wrong, both asserted below:
#
#   * a coarse interval cannot answer before its own tick, so
#     (timeout => 1, interval => 10) could not report before t=10s;
#   * a probe slower than the whole wait holds it open, because the deadline was
#     only ever evaluated after a probe came back.
#
# The elapsed bounds are generous (3x and 3x) so a loaded machine does not fail
# them; the defect they guard against overran by 10x and by unbounded amounts.
push @steps, sub {
    my $t0 = Time::HiRes::time();
    $b->wait_for('#never-ever', timeout => 1, interval => 10, sub {
        $g{coarse_err}  = $_[1];
        $g{coarse_took} = Time::HiRes::time() - $t0;
        $run->();
    });
};
push @steps, sub {
    # a probe that takes ~1s, by AWAITING -- not by spinning. _call_js runs the
    # body inside an async IIFE, so a real sleep costs no CPU.
    my $slow = '(await (async () => { await new Promise(r => setTimeout(r, 1000)); return false })())';
    my $t0 = Time::HiRes::time();
    $b->wait_for_js($slow, timeout => 0.3, interval => 0.05, sub {
        $g{slow_err}  = $_[1];
        $g{slow_took} = Time::HiRes::time() - $t0;
        $run->();
    });
};

# A truthy value whose JSON form THROWS must still satisfy the predicate.
#
# The verdict is computed in JS precisely to survive the JSON boundary -- but
# sending it back in the same payload as the raw value threw that away again
# whenever the value could not be encoded at all: JSON.stringify does not drop a
# circular reference or a BigInt, it THROWS, taking the enclosing object and the
# verdict with it. So wait_for_js('window') timed out (window.window === window),
# and so did any wait on a framework object -- those are made of
# back-references. All three below are truthy from the first poll.
push @steps, sub {
    $b->script('window.circ = {}; window.circ.self = window.circ; window.big = 10n; return 1', sub {
        my @cases = (['circ', 'window.circ'], ['big', 'window.big'], ['win', 'window']);
        my $next; $next = sub {
            my $c = shift @cases or return $run->();
            $b->wait_for_js($c->[1], timeout => 2, sub {
                $g{"unmarshalable_$c->[0]"} = $_[1]; $next->();
            });
        };
        $next->();
    });
};

$b->load_html($fixture, sub { $run->() });
TWK::run_with_timeout(40);

# --- gone ---
ok($g{gone_ok},        'wait_for(gone) resolves once the element is removed');
is($g{gone_err}, undef, 'wait_for(gone): no error');
ok($g{absent_ok},      'wait_for(gone) resolves immediately if it never matched');
is($g{absent_err}, undef, '...with no error');
ok(!$g{stays_ok},      'wait_for(gone) does NOT resolve while the element stays');
is($g{stays_err}, 'timeout', '...it times out');

# --- wait_for_js ---
ok($g{js_val},          'wait_for_js resolves when the predicate becomes true');
is($g{js_err}, undef,   'wait_for_js: no error');
is($g{throw_state}, 'throws',
   'precondition: the predicate really was throwing when the wait started');
ok($g{throw_val},       'wait_for_js polls THROUGH a throwing predicate (window.late.ready)');
is($g{throw_err}, undef, '...and reports no error once it succeeds');

is($g{never_val}, undef, 'a predicate that never holds does not resolve truthily');
like($g{never_err} // '', qr/timeout waiting for: window\.nope === 42/,
     'the timeout message names the expression, not a bare "timeout"');

like($g{bad_err} // '', qr/timeout waiting for/, 'an always-throwing predicate times out');
like($g{bad_err} // '', qr/last JS error/,
     '...and the message carries the last JS error, so a typo is diagnosable');

# --- JS truthiness ---
is($g{fn_err}, undef, 'wait_for_js resolves on a FUNCTION (window.jQuery and friends)')
    or diag('a function is truthy in JS but has no JSON form -- it must not read as false');
is($g{zero_err}, undef, 'wait_for_js resolves on the string "0", which is true in JS');
is($g{zero_val}, '0',   '...and still hands back the value itself');

# --- the timeout is in seconds ---
is($g{coarse_err}, 'timeout', 'a coarse interval still times out');
cmp_ok($g{coarse_took}, '<', 3,
       'timeout => 1, interval => 10 answers in about a second, not about ten')
    or diag(sprintf('took %.2fs -- the deadline is being counted in polls, not seconds', $g{coarse_took}));
like($g{slow_err} // '', qr/timeout waiting for/, 'a slow predicate still times out');
cmp_ok($g{slow_took}, '<', 0.9,
       'a probe slower than the whole wait does not hold it open past its deadline')
    or diag(sprintf('took %.2fs for a 0.3s timeout with a 1s probe', $g{slow_took}));

# --- truthy but unmarshalable ---
is($g{unmarshalable_circ}, undef, 'wait_for_js succeeds on a CIRCULAR object (JSON.stringify throws)')
    or diag('the value failing to encode must not take the verdict down with it');
is($g{unmarshalable_big},  undef, '...on a BigInt');
is($g{unmarshalable_win},  undef, '...and on window itself (window.window === window)');

# --- a page that has poisoned its own world ---
#
# wait_for_js runs the caller's expression in the page's MAIN world, so it is
# marshalled by the page's own JSON.stringify -- and t/49 records the contract
# for main-world calls: they may return a wrong value or a clean error, but they
# must NEVER hang. The predicate below is true from the start, so a naive
# implementation that trusted the marshalled payload could report success on
# forged data; what must happen instead is a clean, bounded timeout.
{
    my $b3 = EV::WebKit->new(window => [200,150], timeout => 10);
    my ($val, $err);
    # The timeout alone does not prove much: the deadline timer answers whatever
    # the poll does, so a poll that DIES every round still times out on schedule
    # and looks identical from the callback. Watch $EV::DIED as well -- that is
    # what tells "polled cleanly and gave up" apart from "threw on every poll
    # into a handler that swallows it, and was rescued by the deadline".
    my @died;
    local $EV::DIED = sub { push @died, "$@" };
    $b3->load_html(<<'HTML', sub {
<script>
  window.ready = true;
  Object.prototype.toJSON = function () { return { evwk_id: 0, evwk_epoch: "FORGED" } };
  JSON.stringify = function () { return '"PWNED"' };
</script>
HTML
        $b3->wait_for_js('window.ready', timeout => 2, sub { ($val, $err) = @_; EV::break });
    });
    TWK::run_with_timeout(20);
    $b3->quit;
    like($err // '', qr/timeout/, 'wait_for_js on a page with a forged JSON.stringify times out cleanly');
    is($val, undef, '...and never reports success on the forged payload');
    is(scalar @died, 0, '...having polled without throwing (the payload shape is checked)')
        or diag("died " . scalar(@died) . " time(s), first: " . ($died[0] // ''));
}

# --- validation ---
{
    my $b2 = EV::WebKit->new(window => [200,150]);
    eval { $b2->wait_for('#x', gone => 1, visible => 1, sub {}) };
    like($@, qr/mutually exclusive/, 'gone and visible together croak');
    eval { $b2->wait_for_js(undef, sub {}) };
    like($@, qr/expression is required/, 'wait_for_js requires an expression');
    eval { $b2->wait_for_js('1', 'not-a-code-ref') };
    like($@, qr/must be a callback/, 'wait_for_js requires a callback');
    $b2->quit;
}

done_testing;
