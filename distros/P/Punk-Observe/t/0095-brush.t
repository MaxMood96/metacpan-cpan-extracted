#!perl
# The two interaction modules.
#
# Where a JS runtime exists this test RUNS them. A regular expression over
# source is not a test of what code does, and the arithmetic in brush.js is
# the part most likely to be silently wrong: nanosecond instants do not fit a
# double, so the endpoints are added digit by digit.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);

my @JS = qw(root/static/nsmath.js root/static/brush.js root/static/livetail.js
            root/static/waterfall.js root/static/flamegraph.js
            root/static/plot.js);

# --- the no-dependency rule is checkable, and therefore checked -------------

for my $f (@JS) {
    ok(-f $f, "$f exists") or next;
    my $src = do { open my $fh, '<', $f or die "$f: $!"; local $/; <$fh> };

    # Comments discuss URLs; code must not fetch one. Strip prose first, the
    # lesson phase 10 paid for by failing on its own documentation.
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;
    $code =~ s{^\s*//.*$}{}gm;

    unlike($code, qr{https?://}, "  $f references no external host");
    unlike($code, qr/\bimport\s|\brequire\s*\(\s*['"][^.]/,
           "  $f imports no package");
    unlike($code, qr/<script|document\.write/, "  $f injects no script");
    like($src, qr/'use strict'|"use strict"/, "  $f is in strict mode");
}

# --- run it -----------------------------------------------------------------

my $node = '';
for my $c (qw(node nodejs)) {
    my $p = `command -v $c 2>/dev/null`;
    chomp $p;
    if ($p && -x $p) { $node = $p; last }
}

SKIP: {
    skip 'no JS runtime found', 26 unless $node;

    my $dir = tempdir(CLEANUP => 1);
    my $out = sub {
        my ($js) = @_;
        my $f = "$dir/run.js";
        open my $fh, '>', $f or die $!;
        print $fh $js;
        close $fh;
        my $r = `$node $f 2>&1`;
        chomp $r;
        return $r;
    };

    # Both modules must LOAD outside a browser without throwing. That is the
    # syntax check, done by the thing that will actually parse them.
    for my $f (@JS) {
        my $r = $out->("require(process.cwd() + '/$f'); console.log('loaded');");
        is($r, 'loaded', "$f parses and loads");
    }

    my $B = "var B = require(process.cwd() + '/root/static/brush.js');";

    # THE ARITHMETIC. A Number holding 1.7e18 is off by hundreds of
    # nanoseconds - invisible on a chart, wrong in a URL, and the URL is what
    # somebody pastes into a query.
    {
        my $r = $out->("$B console.log(B.addNs('1700000000000000000', 1));");
        is($r, '1700000000000000001',
           'one nanosecond added to a 2023 instant is EXACT');

        $r = $out->("$B console.log(Number('1700000000000000000') + 1);");
        isnt($r, '1700000000000000001',
             '  which plain Number arithmetic gets wrong, as designed against');
    }

    {
        my @cases = (
            [ "'0', 0"            => '0'   ],
            [ "'0', 5"            => '5'   ],
            [ "'999', 1"          => '1000' ],
            [ "'1000', -1"        => '999' ],
            [ "'100', -500"       => '0'   ],   # clamped, never negative
            [ "'1700000000000000000', -1" => '1699999999999999999' ],
            [ "'18446744073709551615', 0" => '18446744073709551615' ],
            [ "'1', 0.4"          => '1'   ],   # a fractional pixel rounds
            [ "'1', 0.6"          => '2'   ],
        );
        for my $c (@cases) {
            my $r = $out->("$B console.log(B.addNs($c->[0]));");
            is($r, $c->[1], "addNs($c->[0]) is $c->[1]");
        }
    }

    {
        # Carry and borrow across many digits, which is where a hand-rolled
        # adder goes wrong.
        my $r = $out->("$B console.log(B.addNs('9999999999999999999', 1));");
        is($r, '10000000000000000000', 'a carry propagates through 19 digits');
        $r = $out->("$B console.log(B.addNs('10000000000000000000', -1));");
        is($r, '9999999999999999999', '  and a borrow does too');
    }

    {
        # Against a reference: every result must match Perl's own big-integer
        # arithmetic, not just look plausible.
        require Math::BigInt;
        my $bad = 0;
        my $x = 424242;
        my @pairs;
        for (1 .. 40) {
            $x = ($x * 1103515245 + 12345) % 2147483648;
            my $base  = Math::BigInt->new('1700000000000000000')
                          ->badd($x)->bmul(7)->bstr;
            my $delta = ($x % 2 ? 1 : -1) * ($x % 1_000_003);
            push @pairs, [ $base, $delta ];
        }
        my $js = $B . "var c = [" . join(',', map {
            "['$_->[0]',$_->[1]]" } @pairs) . "];"
          . "console.log(c.map(function(p){return B.addNs(p[0],p[1])}).join(' '));";
        my @got = split ' ', $out->($js);
        for my $i (0 .. $#pairs) {
            my $want = Math::BigInt->new($pairs[$i][0])
                         ->badd($pairs[$i][1]);
            $want = Math::BigInt->new(0) if $want->is_neg;
            $bad++ if ($got[$i] // '') ne $want->bstr;
        }
        is($bad, 0, '40 random shifts all match Math::BigInt exactly');
    }

    # A non-numeric base is returned unchanged rather than becoming NaN in a
    # URL, which would produce a query nothing can answer.
    {
        my $r = $out->("$B console.log(B.addNs('not-a-time', 5));");
        is($r, 'not-a-time', 'a non-numeric base is passed through unchanged');
        $r = $out->("$B console.log(B.addNs('100', Infinity));");
        is($r, '100', '  and an infinite delta changes nothing');
    }

    # Neither module may touch the DOM at load time: they are loaded from the
    # layout on pages that may not carry a chart at all.
    {
        my $r = $out->(
            "global.window = undefined;"
          . "require(process.cwd() + '/root/static/livetail.js');"
          . "require(process.cwd() + '/root/static/brush.js');"
          . "console.log('no-dom-ok');");
        is($r, 'no-dom-ok', 'both modules load with no document at all');
    }
}

done_testing();
