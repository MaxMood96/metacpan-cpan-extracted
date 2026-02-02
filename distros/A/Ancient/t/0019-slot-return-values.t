#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test slot accessor return values

use slot qw(retval1 retval2 retval3);

# ============================================
# Accessor setter returns value
# ============================================

subtest 'accessor setter returns set value' => sub {
    my $result = retval1("test");
    is($result, "test", 'setter returns the set value');
};

subtest 'accessor setter allows chaining pattern' => sub {
    my $val = retval2(42);
    is($val, 42, 'can capture set value');
    is(retval2(), 42, 'value was stored');
};

subtest 'accessor getter returns stored value' => sub {
    retval3("stored");
    my $val = retval3();
    is($val, "stored", 'getter returns stored value');
};

# ============================================
# slot::set return value
# ============================================

subtest 'slot::set returns value' => sub {
    my $result = slot::set('retval1', "via set");
    is($result, "via set", 'slot::set returns set value');
    is(retval1(), "via set", 'value was stored');
};

# ============================================
# slot::set_by_idx return value
# ============================================

subtest 'slot::set_by_idx returns value' => sub {
    my $idx = slot::index('retval2');
    my $result = slot::set_by_idx($idx, "by idx");
    is($result, "by idx", 'slot::set_by_idx returns set value');
    is(retval2(), "by idx", 'value was stored');
};

# ============================================
# Chaining patterns
# ============================================

subtest 'setter in expression' => sub {
    my $upper = uc(retval1("hello"));
    is($upper, "HELLO", 'setter result can be used in expression');
    is(retval1(), "hello", 'original value stored');
};

subtest 'multiple assignments' => sub {
    my $a = retval1("first");
    my $b = retval2("second");
    my $c = retval3("third");
    
    is($a, "first", 'first assignment');
    is($b, "second", 'second assignment');
    is($c, "third", 'third assignment');
};

# ============================================
# Return types
# ============================================

subtest 'accessor returns various types' => sub {
    # Integer
    my $int = retval1(42);
    is($int, 42, 'returns integer');
    
    # Float
    my $float = retval1(3.14);
    is($float, 3.14, 'returns float');
    
    # String
    my $str = retval1("hello");
    is($str, "hello", 'returns string');
    
    # Arrayref
    my $aref = retval1([1, 2, 3]);
    is_deeply($aref, [1, 2, 3], 'returns arrayref');
    
    # Hashref
    my $href = retval1({ key => 'value' });
    is_deeply($href, { key => 'value' }, 'returns hashref');
    
    # Undef
    my $undef = retval1(undef);
    ok(!defined $undef, 'returns undef');
};

done_testing;
