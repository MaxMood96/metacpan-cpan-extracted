#!perl
# The SVG primitives.
#
# The headline assertion is about FORMATTING. Every coordinate is a computed
# double, and the obvious sprintf("%f") is the single most dangerous line
# available in this codebase: a Perl-flavoured formatter reads an NV for %f,
# and the Windows CRT prints three-digit exponents that make a path invalid.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $S = 'Punk::Observe::SVG';
sub fmt  { $S->can('fmt')->($_[0]) }
sub axis { $S->can('axis')->(@_) }

# --- the formatter ----------------------------------------------------------

{
    my %want = (
        0        => '0',
        1        => '1',
        -1       => '-1',
        1.5      => '1.5',
        1.25     => '1.25',
        0.5      => '0.5',
        -0.5     => '-0.5',
        100      => '100',
        1234.567 => '1234.57',
        0.001    => '0',
        -0.001   => '0',
    );
    for my $in (sort { $a <=> $b } keys %want) {
        is(fmt($in), $want{$in}, "fmt($in) is '$want{$in}'");
    }
}

# NO EXPONENT FORM, EVER. `1e-005` in a path attribute is not a valid path,
# and the chart silently does not draw - on one platform, with no error.
{
    my @extreme = (1e-9, 1e-30, -1e-9, 1e12, -1e12, 1e300, -1e300,
                   9**9**9, -9**9**9);
    my $bad = 0;
    for my $v (@extreme) {
        my $s = fmt($v);
        $bad++ if $s =~ /[eE]/;
        $bad++ if $s =~ /nan|inf/i;
    }
    is($bad, 0, 'no extreme value produces an exponent, a nan or an inf');
}

{
    # NaN must become a usable number, not the string "nan". One bad
    # coordinate must cost one point, never the whole path.
    my $nan = 9**9**9 - 9**9**9;
    my $s = fmt($nan);
    unlike($s, qr/nan/i, 'NaN does not reach the output as text');
    like($s, qr/^-?[0-9.]+$/, '  it is a plain number');
}

{
    # Every output must match a strict numeric grammar - that is what a path
    # parser will accept.
    my $bad = 0;
    my $x = 12345;
    for (1 .. 2000) {
        $x = ($x * 1103515245 + 12345) % 2147483648;
        my $v = ($x / 2147483648 - 0.5) * (10 ** (($x % 24) - 12));
        my $s = fmt($v);
        $bad++ unless $s =~ /^-?(0|[1-9][0-9]*)(\.[0-9]{1,2})?$/;
    }
    is($bad, 0, '2000 random values all format to a strict decimal');
}

{
    # And no trailing zero, which is noise in a path.
    is(fmt(1.50), '1.5', 'a trailing zero is trimmed');
    is(fmt(2.00), '2',   '  and a whole number has no point at all');
}

# The source itself must not reach for a formatter.
{
    open my $fh, '<', 'include/punk_observe/po_svg.h' or die;
    local $/;
    my $src = <$fh>;
    $src =~ s{/\*.*?\*/}{}gs;
    unlike($src, qr/\bsprintf\b|\bsnprintf\b|my_snprintf|sv_catpvf/,
           'po_svg.h calls no formatter at all');
    unlike($src, qr/%[0-9.]*[fge]/,
           '  and contains no float format specifier');
}

# --- axes -------------------------------------------------------------------

# An axis labelled 0, 33.33, 66.67, 100 is a chart nobody can read.
{
    my $a = axis(0, 100, 5);
    ok(scalar @{ $a->{ticks} } >= 3, 'an axis over 0..100 has ticks');
    my $bad = grep { $_ !~ /^-?(0|[1-9][0-9]*)(\.[0-9]{1,2})?$/ } @{ $a->{ticks} };
    is($bad, 0, '  all formatted as plain decimals');
    is($a->{ticks}[0], '0', '  starting at a round number');

    # Every tick must be a multiple of the step: that IS "nice".
    my $step = $a->{step};
    my $off = 0;
    for my $t (@{ $a->{ticks} }) {
        my $r = abs($t / $step - int($t / $step + 0.5));
        $off++ if $r > 1e-6;
    }
    is($off, 0, '  and every tick is a multiple of the step');
}

{
    my $a = axis(0, 1000, 5);
    ok(0 + $a->{hi} >= 1000, 'the axis covers the maximum');
    ok(0 + $a->{lo} <= 0,    '  and the minimum');
}

{
    # A range spanning a decade.
    for my $hi (1, 10, 100, 1000, 10000, 100000) {
        my $a = axis(0, $hi, 5);
        ok(0 + $a->{hi} >= $hi, "an axis to $hi covers it");
        cmp_ok(scalar @{ $a->{ticks} }, '>=', 2, "  with at least two ticks");
        cmp_ok(scalar @{ $a->{ticks} }, '<=', 16, "  and not more than sixteen");
    }
}

{
    # A FLAT series is a real case - a gauge that has not moved - and a range
    # of zero would divide by zero.
    my $a = axis(42, 42, 5);
    cmp_ok(scalar @{ $a->{ticks} }, '>=', 2, 'a flat series still gets an axis');
    cmp_ok(0 + $a->{lo}, '<', 42, '  with the value inside the band');
    cmp_ok(0 + $a->{hi}, '>', 42, '  not on an edge');
}

{
    my $a = axis(0, 0, 5);
    cmp_ok(scalar @{ $a->{ticks} }, '>=', 2, 'an all-zero series gets an axis');
}

{
    my $a = axis(-50, 50, 5);
    ok(0 + $a->{lo} <= -50, 'a range crossing zero covers the negative end');
    ok(0 + $a->{hi} >=  50, '  and the positive end');
}

# --- paths ------------------------------------------------------------------

{
    my $d = $S->can('line')->([ 0, 1, 2, 3 ], [ 0, 10, 5, 20 ], 100, 50);
    like($d, qr/^M/, 'a path starts with a moveto');
    my @cmds = ($d =~ /([ML])/g);
    is(scalar @cmds, 4, '  with one command per point');
    unlike($d, qr/[eE]/, '  and no exponent anywhere in it');
    unlike($d, qr/nan|inf/i, '  and no nan or inf');

    # y grows downward in SVG and upward on a chart.
    my ($first_y) = $d =~ /^M[\d.-]+ ([\d.-]+)/;
    my ($last_y)  = $d =~ /([\d.-]+)$/;
    cmp_ok($first_y, '>', $last_y,
           'the highest value is nearest the top, so y was flipped');
}

{
    my $d = $S->can('line')->([ 0 ], [ 5 ], 100, 50);
    like($d, qr/^M/, 'a single point still produces a path');
}

{
    # A flat series must not divide by zero and must not produce nan.
    my $d = $S->can('line')->([ 0, 1, 2 ], [ 7, 7, 7 ], 100, 50);
    unlike($d, qr/nan|inf/i, 'a flat series produces no nan');
    like($d, qr/^M/, '  and still draws');
}

# --- escaping ---------------------------------------------------------------

# SVG ATTRIBUTE CONTEXT IS NOT HTML TEXT CONTEXT. A span name containing a
# quote ends the attribute early and everything after it becomes markup.
{
    my $e = $S->can('esc_attr');
    is($e->('plain'), 'plain', 'plain text is unchanged');
    is($e->('a"b'),  'a&quot;b', 'a double quote is escaped');
    is($e->("a'b"),  'a&#39;b',  'a single quote is escaped');
    is($e->('a&b'),  'a&amp;b',  'an ampersand is escaped');
    is($e->('a<b>c'),'a&lt;b&gt;c', 'angle brackets are escaped');

    my $attack = '" onload="alert(1)';
    my $safe = $e->($attack);
    unlike($safe, qr/"/, 'an attribute-breaking payload has no bare quote left');
    like($safe, qr/&quot;/, '  it is entity-encoded');

    is($e->("caf\xc3\xa9"), "caf\xc3\xa9",
       'multi-byte UTF-8 passes through as bytes');
    my $ctl = $e->("a\x00b\x07c");
    unlike($ctl, qr/[\x00-\x08]/, 'control characters are dropped, not encoded');
    is($ctl, 'abc', '  leaving the printable text');
    is($e->("a\tb"), "a\tb", 'a tab survives, being legal in XML');
}

done_testing();
