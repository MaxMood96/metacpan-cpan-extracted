#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 30;

use Stefo;

# =============================================================================
# index() tests - now fixed
# =============================================================================

# index() with >= 0 check (contains)
{
    my $idx = Stefo::compile(sub { index($_, 'bar') >= 0 });
    ok(Stefo::is_optimized($idx), "index(\$_, 'bar') >= 0 optimized");
    ok(Stefo::check($idx, 'foobar'), "index('foobar', 'bar') >= 0");
    ok(Stefo::check($idx, 'bar'), "index('bar', 'bar') >= 0");
    ok(Stefo::check($idx, 'barbaz'), "index('barbaz', 'bar') >= 0");
    ok(!Stefo::check($idx, 'foo'), "index('foo', 'bar') < 0");
}

# index() == 0 (starts with)
{
    my $starts = Stefo::compile(sub { index($_, 'foo') == 0 });
    ok(Stefo::is_optimized($starts), "index(\$_, 'foo') == 0 optimized");
    ok(Stefo::check($starts, 'foobar'), "index('foobar', 'foo') == 0");
    ok(Stefo::check($starts, 'foo'), "index('foo', 'foo') == 0");
    ok(!Stefo::check($starts, 'barfoo'), "index('barfoo', 'foo') != 0");
}

# =============================================================================
# rindex() tests
# =============================================================================

{
    my $ridx = Stefo::compile(sub { rindex($_, 'a') > 0 });
    ok(Stefo::is_optimized($ridx), "rindex(\$_, 'a') > 0 optimized");
    ok(Stefo::check($ridx, 'banana'), "rindex('banana', 'a') = 5 > 0");
    ok(Stefo::check($ridx, 'aa'), "rindex('aa', 'a') = 1 > 0");
    ok(!Stefo::check($ridx, 'a'), "rindex('a', 'a') = 0, not > 0");
    ok(!Stefo::check($ridx, 'bbb'), "rindex('bbb', 'a') = -1, not > 0");
}

# =============================================================================
# substr() tests
# =============================================================================

# substr with 3 args
{
    my $sub3 = Stefo::compile(sub { substr($_, 0, 3) eq 'foo' });
    ok(Stefo::is_optimized($sub3), "substr(\$_, 0, 3) eq 'foo' optimized");
    ok(Stefo::check($sub3, 'foobar'), "substr('foobar', 0, 3) eq 'foo'");
    ok(Stefo::check($sub3, 'foo'), "substr('foo', 0, 3) eq 'foo'");
    ok(!Stefo::check($sub3, 'barfoo'), "substr('barfoo', 0, 3) ne 'foo'");
}

# substr with 2 args (from position to end)
{
    my $sub2 = Stefo::compile(sub { substr($_, 3) eq 'bar' });
    ok(Stefo::is_optimized($sub2), "substr(\$_, 3) eq 'bar' optimized");
    ok(Stefo::check($sub2, 'foobar'), "substr('foobar', 3) eq 'bar'");
    ok(!Stefo::check($sub2, 'foobaz'), "substr('foobaz', 3) ne 'bar'");
}

# substr with negative position
{
    my $sub_neg = Stefo::compile(sub { substr($_, -3) eq 'bar' });
    ok(Stefo::is_optimized($sub_neg), "substr(\$_, -3) eq 'bar' optimized");
    ok(Stefo::check($sub_neg, 'foobar'), "substr('foobar', -3) eq 'bar'");
    ok(Stefo::check($sub_neg, 'bar'), "substr('bar', -3) eq 'bar'");
    ok(!Stefo::check($sub_neg, 'barbaz'), "substr('barbaz', -3) ne 'bar'");
}

# =============================================================================
# String concatenation (.)
# =============================================================================

{
    my $concat = Stefo::compile(sub { $_ . '!' eq 'hello!' });
    # Note: concat may not be optimized but should work via fallback
    ok(Stefo::check($concat, 'hello'), "'hello' . '!' eq 'hello!'");
    ok(!Stefo::check($concat, 'world'), "'world' . '!' ne 'hello!'");
}

# Combined patterns
{
    my $combo = Stefo::compile(sub { index($_, 'foo') == 0 && length($_) > 3 });
    ok(Stefo::is_optimized($combo), "index==0 && length>3 optimized");
    ok(Stefo::check($combo, 'foobar'), "'foobar' starts with 'foo' and len > 3");
    ok(!Stefo::check($combo, 'foo'), "'foo' starts with 'foo' but len == 3");
}
