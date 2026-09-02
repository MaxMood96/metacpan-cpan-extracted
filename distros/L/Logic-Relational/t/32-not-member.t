#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;

logic NotMemberTest {
    rule is_absent($x, $list) {
        not_member($x, $list);
    }
}

# Test 1: Element not in list succeeds
query NotMemberTest::is_absent('apple', ['banana', 'cherry', 'date']) -> my $q1;
ok($q1->next, "'apple' is not member of ['banana', 'cherry', 'date']");

# Test 2: Element in list fails
query NotMemberTest::is_absent('cherry', ['banana', 'cherry', 'date']) -> my $q2;
ok(!$q2->next, "'cherry' is member of ['banana', 'cherry', 'date'] (fails not_member)");

# Test 3: Empty list succeeds
query NotMemberTest::is_absent('anything', []) -> my $q3;
ok($q3->next, "element is not member of empty list");

done_testing;
