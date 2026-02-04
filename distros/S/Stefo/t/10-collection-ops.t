#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 18;

use Stefo;

# =============================================================================
# Collection Operations
# Note: Some patterns use Perl fallback but still work correctly
# =============================================================================

# scalar(@{$_}) - array length via dereference
{
    my $alen = Stefo::compile(sub { scalar(@{$_}) > 3 });
    ok(Stefo::is_optimized($alen), "scalar(\@{\$_}) > 3 optimized");
    ok(Stefo::check($alen, [1,2,3,4]), "scalar([1,2,3,4]) = 4 > 3");
    ok(Stefo::check($alen, [1,2,3,4,5]), "scalar([1,2,3,4,5]) = 5 > 3");
}

# quotemeta
{
    my $qm = Stefo::compile(sub { quotemeta($_) eq '\.\*' });
    ok(Stefo::is_optimized($qm), "quotemeta(\$_) eq '\\.\\*' optimized");
    ok(Stefo::check($qm, '.*'), "quotemeta('.*') eq '\\.\\*'");
    ok(!Stefo::check($qm, 'foo'), "quotemeta('foo') ne '\\.\\*'");
}

# =============================================================================
# Element Access (via Perl fallback)
# These work but may not be marked as "optimized"
# =============================================================================

# Array element access
{
    my $elem0 = Stefo::compile(sub { $_->[0] > 5 });
    ok(Stefo::check($elem0, [10, 2, 3]), "[10,2,3]->[0] = 10 > 5");
    ok(Stefo::check($elem0, [100]), "[100]->[0] = 100 > 5");
    ok(!Stefo::check($elem0, [3, 10, 20]), "[3,10,20]->[0] = 3 < 5");
    ok(!Stefo::check($elem0, [5]), "[5]->[0] = 5, not > 5");
}

# Hash element access
{
    my $helem = Stefo::compile(sub { $_->{name} eq 'Alice' });
    ok(Stefo::check($helem, {name => 'Alice', age => 30}), "{name=>'Alice'}->{name} eq 'Alice'");
    ok(!Stefo::check($helem, {name => 'Bob'}), "{name=>'Bob'}->{name} ne 'Alice'");
}

# exists check
{
    my $exists = Stefo::compile(sub { exists $_->{key} });
    ok(Stefo::check($exists, {key => 'value'}), "exists {key=>'value'}->{key}");
    ok(Stefo::check($exists, {key => undef}), "exists {key=>undef}->{key}");
    ok(!Stefo::check($exists, {other => 'value'}), "not exists {other=>'value'}->{key}");
    ok(!Stefo::check($exists, {}), "not exists {}->{key}");
}

# scalar(keys %{$_}) - hash size
{
    my $hsize = Stefo::compile(sub { scalar(keys %{$_}) == 2 });
    ok(Stefo::check($hsize, {a => 1, b => 2}), "keys {a,b} = 2");
    ok(!Stefo::check($hsize, {a => 1}), "keys {a} = 1 != 2");
}
