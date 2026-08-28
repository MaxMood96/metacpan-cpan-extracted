use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# select_option / check / uncheck / hover / scroll_into_view.
#
# ONE instance and ONE EV::run for the whole chain, deliberately: t/42 records
# that a second EV::run in the same process, after a long series of sequential
# _call_js round trips, reliably hangs at 100% CPU. That is a pre-existing bug
# unrelated to these atoms, and this file must not walk into it.
#
# The steps are queued rather than nested so the chain stays readable at ten
# deep; it is still a single EV::run, which is the part that matters.

my $b = EV::WebKit->new(window => [400, 300]);
my %g;

my $fixture = <<'HTML';
<style>#far { margin-top: 3000px }</style>
<select id=sel>
  <option value="a">Alpha</option>
  <option value="b">Beta</option>
  <option value="">Blank Label</option>
  <option value="5">Five</option>
</select>
<input type=checkbox id=cb>
<input type=radio name=r id=r1>
<div id=hov>hover me</div>
<div id=far>far below the fold</div>
<script>
  window.__ev = { sel: 0, cb: 0, hov: [] };
  document.getElementById('sel').addEventListener('change', () => window.__ev.sel++);
  document.getElementById('cb').addEventListener('change',  () => window.__ev.cb++);
  for (const t of ['mouseover','mouseenter','mousemove','pointerover','pointerenter'])
    document.getElementById('hov').addEventListener(t, () => window.__ev.hov.push(t));
  // the DEVICE a pointer event claims to come from -- see the assertions
  window.__ev.ptr = null;
  document.getElementById('hov').addEventListener('pointerover',
    e => window.__ev.ptr = [e.pointerType, e.pointerId, e.isPrimary]);
</script>
HTML

# each step: [ description, coderef($next) ]
my @steps;
my $run_next; $run_next = sub {
    my $s = shift @steps or return EV::break;
    $s->[1]->($run_next);
};

sub step { push @steps, [@_] }

my %el;
step('find' => sub {
    my $next = shift;
    # a plain list, not qw(): '#' inside qw() reads as a comment and warns
    my @want = ('#sel', '#cb', '#r1', '#hov', '#far');
    my $left = scalar @want;
    for my $sel (@want) {
        $b->find($sel, sub {
            my ($e, $err) = @_;
            $el{$sel} = $e; $g{"find$sel"} = $err // ($e ? 'ok' : 'missing');
            $next->() unless --$left;
        });
    }
});

step('select_option by value' => sub {
    my $next = shift;
    $el{'#sel'}->select_option('b', sub { ($g{sel_val}, $g{sel_err}) = @_; $next->() });
});

# A NUMBER where the DOM keeps a string. An option's value is always a string
# and the match is ===, which does not coerce, so an unstringified 5 encoded as
# a JSON number matched nothing -- select_option(5) failed on <option value="5">
# while select_option('5') worked. Perl draws no such distinction anywhere else.
step('select_option with a numeric value' => sub {
    my $next = shift;
    $el{'#sel'}->select_option(5, sub { ($g{num_val}, $g{num_err}) = @_; $next->() });
});

step('select_option by label' => sub {
    my $next = shift;
    # "Blank Label" has an EMPTY value, so a value-only implementation cannot
    # reach it -- this is what pins the label fallback.
    $el{'#sel'}->select_option('Blank Label', sub { ($g{lbl_val}, $g{lbl_err}) = @_; $next->() });
});

step('check' => sub {
    my $next = shift;
    $el{'#cb'}->check(sub { ($g{chk1}, $g{chk1_err}) = @_; $next->() });
});

step('check again (idempotent)' => sub {
    my $next = shift;
    $el{'#cb'}->check(sub { ($g{chk2}, $g{chk2_err}) = @_; $next->() });
});

step('uncheck' => sub {
    my $next = shift;
    $el{'#cb'}->uncheck(sub { ($g{unchk}, $g{unchk_err}) = @_; $next->() });
});

step('radio check' => sub {
    my $next = shift;
    $el{'#r1'}->check(sub { ($g{radio}, $g{radio_err}) = @_; $next->() });
});

step('check on a non-checkbox errors' => sub {
    my $next = shift;
    $el{'#sel'}->check(sub { ($g{bad_chk}, $g{bad_chk_err}) = @_; $next->() });
});

step('select_option on a non-select errors' => sub {
    my $next = shift;
    $el{'#cb'}->select_option('x', sub { ($g{bad_sel}, $g{bad_sel_err}) = @_; $next->() });
});

step('hover' => sub {
    my $next = shift;
    $el{'#hov'}->hover(sub { ($g{hov}, $g{hov_err}) = @_; $next->() });
});

step('scroll_into_view' => sub {
    my $next = shift;
    $el{'#far'}->scroll_into_view(sub { ($g{scr}, $g{scr_err}) = @_; $next->() });
});

step('collect page state' => sub {
    my $next = shift;
    $b->script('return JSON.stringify({ ev: window.__ev, selValue: document.getElementById("sel").value,'
             . ' cbChecked: document.getElementById("cb").checked,'
             . ' radioChecked: document.getElementById("r1").checked,'
             . ' scrollY: Math.round(window.scrollY) })',
        sub { $g{state} = $_[0]; $next->() });
});

$b->load_html($fixture, sub { $run_next->() });
TWK::run_with_timeout(30);
$b->quit;

is($g{'find#sel'}, 'ok', 'fixture elements found') or diag explain \%g;
require Cpanel::JSON::XS;
my $st = eval { Cpanel::JSON::XS::decode_json($g{state} // '{}') } || {};

# --- select_option ---
is($g{sel_err}, undef, 'select_option: no error');
is($g{sel_val}, 'b',   'select_option returns the selected value');
is($g{lbl_val}, '',    'select_option matches by visible LABEL when no value matches');
is($g{lbl_err}, undef, 'select_option by label: no error');
is($g{num_err}, undef, 'select_option accepts a NUMBER for a string option value')
    or diag('=== does not coerce: an unstringified 5 never matches value="5"');
is($g{num_val}, '5',   '...and reports the value it selected');
is($st->{selValue}, '', 'the <select> really holds the label-matched option');
is($st->{ev}{sel}, 3,  'each select_option fired exactly one change event');

# --- check / uncheck ---
is($g{chk1}, 1, 'check() reports checked');
is($g{chk2}, 1, 'check() on an already-checked box still reports checked');
is($g{unchk}, 0, 'uncheck() reports unchecked');
ok(!$st->{cbChecked}, 'the checkbox ends unchecked');
# 2 events, not 3: the idempotent second check() must NOT fire change
is($st->{ev}{cb}, 2, 'check/check/uncheck fired 2 change events -- the redundant check was a no-op');
is($g{radio}, 1, 'check() works on a radio');
ok($st->{radioChecked}, 'the radio is checked');

# --- wrong element type errors, rather than silently doing nothing ---
like($g{bad_chk_err} // '', qr/checkbox or radio/, 'check() on a <select> errors');
like($g{bad_sel_err} // '', qr/not a <select>/,    'select_option on a checkbox errors');

# --- hover ---
is($g{hov_err}, undef, 'hover: no error');
my %seen = map { $_ => 1 } @{ $st->{ev}{hov} || [] };
ok($seen{mouseover},  'hover fires mouseover');
ok($seen{mousemove},  'hover fires mousemove');
# mouseenter does NOT bubble -- a naive implementation that only dispatches
# mouseover misses it, and a menu that opens on mouseenter would never open
ok($seen{mouseenter}, 'hover fires mouseenter (the non-bubbling one)');

# ...and the pointer events claim a MOUSE. Built without these, a PointerEvent
# reports pointerType "" and isPrimary false, so a menu that branches on the
# device -- `if (e.pointerType !== "touch")`, or a guard on isPrimary -- took the
# wrong branch or none at all, which is the very class of menu hover exists for.
is(($st->{ev}{ptr} || [])->[0], 'mouse', 'hover reports pointerType "mouse", not ""');
is(($st->{ev}{ptr} || [])->[1], 1,       '...a real pointerId');
ok(($st->{ev}{ptr} || [])->[2],          '...and isPrimary true');

# --- scroll_into_view ---
is($g{scr_err}, undef, 'scroll_into_view: no error');
cmp_ok($st->{scrollY}, '>', 100, "scroll_into_view actually scrolled (scrollY=$st->{scrollY})");

done_testing;
