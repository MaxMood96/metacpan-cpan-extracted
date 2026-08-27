#!perl
# The time range picker.
#
# Two things here are worth testing and neither is visible in the markup: the
# conversion from a calendar's milliseconds to a nanosecond instant, which a
# double gets numerically wrong and only prints correctly by accident, and the
# rule that a NAMED range stays named rather than being frozen into the two
# instants it happened to resolve to.
#
# So where a JS runtime exists this RUNS daterange.js against a DOM small
# enough to fit in this file and the real moment.js the browser would get. A
# regular expression over the source would confirm the code was written, not
# that it works.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use File::Raw::JSON ();

my $JS = 'root/static/daterange.js';

# --- the same no-dependency rule the other modules are held to --------------

ok(-f $JS, "$JS exists") or do { done_testing(); exit };
my $src = do { open my $fh, '<', $JS or die "$JS: $!"; local $/; <$fh> };
{
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;
    $code =~ s{^\s*//.*$}{}gm;
    unlike($code, qr{https?://},   '  it references no external host');
    unlike($code, qr/<script|document\.write/, '  it injects no script');
    like($src, qr/'use strict'/,   '  it is in strict mode');
}

# THE BUTTONS ARE THE FALLBACK, so the class that hides them must be added
# after the picker is built and nowhere else. This one IS a source check,
# because it is a claim about ordering that no single run can demonstrate.
{
    my @add = $src =~ /classList\.add\('picked'\)/g;
    is(scalar @add, 1, 'the row of buttons is hidden in exactly one place');
    my $at = index($src, "classList.add('picked')");
    my $ctor = index($src, 'new DateRangePicker(');
    ok($ctor >= 0 && $at > $ctor,
       '  and only after the picker has been constructed');
}

my $node = '';
for my $c (qw(node nodejs)) {
    my $p = `command -v $c 2>/dev/null`;
    chomp $p;
    if ($p && -x $p) { $node = $p; last }
}

SKIP: {
    skip 'no JS runtime found', 22 unless $node;

    my $dir = tempdir(CLEANUP => 1);
    copy('root/static/moment.min.js', "$dir/moment.min.js") or die $!;
    copy('root/static/nsmath.js',     "$dir/nsmath.js")     or die $!;
    copy($JS,                         "$dir/daterange.js")  or die $!;

    open my $hfh, '>', "$dir/run.js" or die $!;
    print $hfh <<'HARNESS';
'use strict';
var fs = require('fs');
var moment = require('./moment.min.js');
var nsSrc = fs.readFileSync(__dirname + '/nsmath.js', 'utf8');
var drSrc = fs.readFileSync(__dirname + '/daterange.js', 'utf8');

/* --- a DOM, in exactly the amount daterange.js touches ------------------- */
function El(tag) {
    this.tagName = tag;
    this.attrs = {};
    this.children = [];
    this.parentNode = null;
    this.className = '';
    var self = this;
    this._cls = {};
    this.classList = {
        add:      function (c) { self._cls[c] = 1; },
        contains: function (c) { return !!self._cls[c]; }
    };
}
El.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); };
El.prototype.getAttribute = function (k) {
    return Object.prototype.hasOwnProperty.call(this.attrs, k) ? this.attrs[k] : null;
};
El.prototype.appendChild = function (c) {
    c.parentNode = this; this.children.push(c); return c;
};
El.prototype.removeChild = function (c) {
    var i = this.children.indexOf(c);
    if (i >= 0) this.children.splice(i, 1);
    c.parentNode = null;
    return c;
};
El.prototype.insertBefore = function (c, ref) {
    c.parentNode = this;
    var i = ref ? this.children.indexOf(ref) : -1;
    if (i < 0) this.children.push(c); else this.children.splice(i, 0, c);
    return c;
};
Object.defineProperty(El.prototype, 'firstChild', {
    get: function () { return this.children[0] || null; }
});
El.prototype.walk = function () {
    var out = [];
    (function rec(n) {
        for (var i = 0; i < n.children.length; i++) {
            out.push(n.children[i]);
            rec(n.children[i]);
        }
    })(this);
    return out;
};
/* Only the four selector shapes daterange.js actually asks for. A general
 * selector engine here would be a second thing to get wrong. */
El.prototype.matches = function (sel) {
    var m;
    if (sel === 'form') return this.tagName === 'form';
    if (sel === '[data-rangepick]')
        return Object.prototype.hasOwnProperty.call(this.attrs, 'data-rangepick');
    if ((m = /^\.([\w-]+)$/.exec(sel)))
        return this.className === m[1] || !!this._cls[m[1]];
    if ((m = /^input\[type=hidden\]\[name=([\w-]+)\]$/.exec(sel)))
        return this.tagName === 'input' && this.type === 'hidden'
            && this.name === m[1];
    return false;
};
El.prototype.querySelector = function (s) {
    var d = this.walk();
    for (var i = 0; i < d.length; i++) if (d[i].matches(s)) return d[i];
    return null;
};
El.prototype.querySelectorAll = function (s) {
    return this.walk().filter(function (e) { return e.matches(s); });
};
El.prototype.closest = function (s) {
    var n = this;
    while (n) { if (n.matches(s)) return n; n = n.parentNode; }
    return null;
};

var PRESETS = [
    ['15m', 'last 15 minutes'], ['1h',  'last hour'],
    ['6h',  'last 6 hours'],    ['24h', 'last 24 hours'],
    ['7d',  'last 7 days'],     ['30d', 'last 30 days'],
    ['all', 'everything']
];

function hidden(name, value) {
    var el = new El('input');
    el.type = 'hidden'; el.name = name; el.value = value;
    return el;
}

/* Builds a page, installs the globals, and runs the module over it. */
function scenario(opt) {
    opt = opt || {};
    var root = new El('div');
    var form = new El('form');
    root.appendChild(form);
    form.appendChild(hidden('range', opt.range === undefined ? '1h' : opt.range));
    if (opt.from) { form.appendChild(hidden('from', opt.from));
                    form.appendChild(hidden('to', opt.to)); }

    var host = new El('span');
    host.className = 'rangepick';
    host.setAttribute('data-rangepick', '');
    if (!opt.noHost) form.appendChild(host);
    if (!opt.noButtons)
        PRESETS.forEach(function (p) {
            var b = new El('button');
            b.className = 'rangebtn';
            b.setAttribute('value', p[0]);
            b.setAttribute('title', p[1]);
            host.appendChild(b);
        });

    form.submitted = 0;
    form.requestSubmit = function () { form.submitted++; };
    form.submit = function () { form.submitted++; };

    var built = null;
    global.window = {};
    global.document = {
        body: root,
        createElement: function (t) { return new El(t); },
        querySelector: function (s) { return root.querySelector(s); }
    };
    global.moment = moment;
    global.DateRangePicker = opt.noPicker ? undefined : function (el, o, cb) {
        if (opt.throws) throw new Error('nope');
        built = { el: el, opts: o, cb: cb };
    };

    /* nsmath first, same as the page: `defer` runs in document order. */
    (new Function(nsSrc))();
    var threw = null;
    try { (new Function(drSrc))(); } catch (e) { threw = String(e); }

    return {
        root: root, form: form, host: host, built: built, threw: threw,
        field: function (n) {
            return form.querySelector('input[type=hidden][name=' + n + ']');
        }
    };
}

var out = {};

/* 1. No control on the page at all. */
{
    var s = scenario({ noHost: true });
    out.no_host_threw = s.threw;
}

/* 2. The picker script did not load. The buttons must survive. */
{
    var s = scenario({ noPicker: true });
    out.no_picker_threw  = s.threw;
    out.no_picker_picked = s.host.classList.contains('picked');
    out.no_picker_input  = !!s.host.querySelector('.rangeinput');
}

/* 3. The picker threw while building. Same requirement. */
{
    var s = scenario({ throws: true });
    out.throws_threw  = s.threw;
    out.throws_picked = s.host.classList.contains('picked');
    out.throws_input  = !!s.host.querySelector('.rangeinput');
    out.throws_buttons = s.host.children.length;
}

/* 4. The ordinary case. */
{
    var s = scenario({ range: '6h' });
    out.ok_threw   = s.threw;
    out.ok_picked  = s.host.classList.contains('picked');
    out.ok_first   = s.host.firstChild ? s.host.firstChild.className : null;
    out.ok_value   = s.host.firstChild ? s.host.firstChild.value : null;
    out.ok_readonly = s.host.firstChild ? !!s.host.firstChild.readOnly : false;
    out.ok_from_created = !!s.field('from');
    out.ok_to_created   = !!s.field('to');
    out.ok_from_empty   = s.field('from') ? s.field('from').value : 'MISSING';
    out.ok_ranges = s.built ? Object.keys(s.built.opts.ranges) : null;
    out.ok_submitted = s.form.submitted;
}

/* 5. A preset is applied. The KEY is submitted, not the two instants. */
{
    var s = scenario({ range: '1h' });
    s.built.cb(moment(1755000000123), moment(1755000600456), 'last 6 hours');
    out.preset_range = s.field('range').value;
    out.preset_from  = s.field('from').value;
    out.preset_to    = s.field('to').value;
    out.preset_text  = s.host.firstChild.value;
    out.preset_submitted = s.form.submitted;
}

/* 6. `all` is a preset like any other, resolved back from its label. */
{
    var s = scenario({ range: '1h' });
    s.built.cb(moment(0), moment(), 'everything');
    out.all_range = s.field('range').value;
    out.all_from  = s.field('from').value;
}

/* 7. A custom window. THE INSTANTS MUST BE EXACT. */
{
    var s = scenario({ range: '1h' });
    s.built.cb(moment(1755000000123), moment(1755000600456), 'Custom');
    out.custom_range = s.field('range').value;
    out.custom_from  = s.field('from').value;
    out.custom_to    = s.field('to').value;
    /* The same conversion done in a double. It PRINTS correctly, because
     * String() emits the shortest decimal that round-trips; the number it
     * printed from is not the instant. */
    out.naive_printed = String(1755000000123 * 1e6);
    out.naive_actual  = BigInt(1755000000123 * 1e6).toString();
}

/* 8. A custom window already in the URL seeds the calendar. */
{
    var s = scenario({ range: 'custom',
                       from: '1755000000123000000', to: '1755000600456000000' });
    out.seed_start = s.built ? s.built.opts.startDate.valueOf() : null;
    out.seed_end   = s.built ? s.built.opts.endDate.valueOf()   : null;
}

process.stdout.write(JSON.stringify(out));
HARNESS
    close $hfh;

    my $raw = `$node $dir/run.js 2>&1`;
    my $r = eval { File::Raw::JSON::file_json_decode($raw) };
    if (!$r) {
        diag("harness output: $raw");
        fail('the harness ran') for 1 .. 22;
        last SKIP;
    }

    is($r->{no_host_threw}, undef, 'a page with no range control is a no-op');

    is($r->{no_picker_threw}, undef, 'a missing picker library is not an error');
    ok(!$r->{no_picker_picked}, '  and the preset buttons are left alone');
    ok(!$r->{no_picker_input},  '  and no dead input is left behind');

    is($r->{throws_threw}, undef, 'a picker that throws is not an error either');
    ok(!$r->{throws_picked}, '  the preset buttons still work');
    ok(!$r->{throws_input},  '  and the input it was for is removed');
    is($r->{throws_buttons}, 7, '  leaving exactly the seven buttons');

    is($r->{ok_threw}, undef, 'the ordinary case runs clean');
    ok($r->{ok_picked}, '  the buttons give way to the picker');
    is($r->{ok_first}, 'rangeinput', '  which is first in the control');
    is($r->{ok_value}, 'last 6 hours', '  showing the active range by name');
    ok($r->{ok_readonly}, '  and not typeable, because the calendar is the editor');
    ok($r->{ok_from_created} && $r->{ok_to_created},
       '  the from/to fields are created for the picker to fill');
    is($r->{ok_from_empty}, '',
       '  and start EMPTY, which the server reads as absent');
    is_deeply($r->{ok_ranges},
              ['last 15 minutes', 'last hour', 'last 6 hours', 'last 24 hours',
               'last 7 days', 'last 30 days', 'everything'],
              '  every server-side preset reaches the menu, in order');
    is($r->{ok_submitted}, 0, '  and nothing is submitted on load');

    # A NAMED RANGE STAYS NAMED. Submitting the instants a preset resolved to
    # would freeze it, so "last 15 minutes" would stop meaning the last fifteen
    # minutes fifteen minutes later.
    is($r->{preset_range}, '6h', 'a preset submits its key');
    is("$r->{preset_from}$r->{preset_to}", '',
       '  and clears the two instants rather than freezing the window');
    is($r->{preset_submitted}, 1, '  and applies immediately, as the button did');

    is($r->{all_range}, 'all', "`all` comes back as a key too, not as 1970");
    is($r->{all_from}, '', '  unbounded, not bounded at the epoch');

    is($r->{custom_range}, 'custom', 'a custom window submits from/to');
    is($r->{custom_from}, '1755000000123000000', '  to the exact nanosecond');
    is($r->{custom_to},   '1755000600456000000', '  at both ends');
    # The digits are multiplied as digits rather than through a double. The
    # double gets the right STRING for a whole millisecond - String() prints
    # the shortest decimal that round-trips - and holds the wrong number while
    # doing it, which is a property of the formatter to be leaning on.
    is($r->{naive_printed}, '1755000000123000000',
       '  the same value through a double prints the same');
    is($r->{naive_actual}, '1755000000123000064',
       '  while being 64ns from the instant it claims to be');

    is($r->{seed_start}, 1755000000123,
       'a custom window in the URL opens the calendar on itself');
    is($r->{seed_end}, 1755000600456, '  at both ends');
}

done_testing();
