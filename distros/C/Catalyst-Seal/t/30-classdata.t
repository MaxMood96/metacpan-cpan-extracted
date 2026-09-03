#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require Catalyst::Seal::ClassData;
require Class::MOP;
require SealTest::Data;

# A child of the sealed class, created before sealing, with a value of its own
# for one attribute and nothing of its own for the rest.
{
    package SealTest::Data::Child;
    use Moose;
    extends 'SealTest::Data';
    __PACKAGE__->cd_inherited('from the child');
    __PACKAGE__->meta->make_immutable;
}

my @attrs = SealTest::Data->attributes;

# Discovery finds them all, and finds nothing that is not one.
{
    my %found = Catalyst::Seal::ClassData::_classdata_accessors('SealTest::Data');
    for my $a (@attrs) {
        ok(exists $found{$a}, "discovery found $a");
    }
    ok(!exists $found{attributes}, 'and did not mistake an ordinary method for one');
    ok(!exists $found{meta},       'or the metaclass accessor');
}

# Record what stock returns, then seal, then compare.
my %before = map { $_ => [ SealTest::Data->$_ ] } @attrs;
my %child_before = map { $_ => [ SealTest::Data::Child->$_ ] } @attrs;

my $sealed = Catalyst::Seal::ClassData::_seal_class('SealTest::Data');
cmp_ok($sealed, '>=', scalar @attrs, 'every attribute was sealed');
Catalyst::Seal::ClassData::_seal_class('SealTest::Data::Child');

for my $a (@attrs) {
    is_deeply([ SealTest::Data->$a ], $before{$a}, "$a reads the same after sealing");
    is_deeply([ SealTest::Data::Child->$a ], $child_before{$a},
        "$a reads the same on the child");
    is_deeply([ SealTest::Data->${\"_${a}_accessor"} ], $before{$a},
        "_${a}_accessor agrees with $a");
}

# The falsy ones specifically, because is_deeply on [undef] and [''] both pass
# a careless implementation that returns undef for everything.
is(SealTest::Data->cd_zero,  0,  'a zero value is still zero');
is(SealTest::Data->cd_empty, '', 'an empty string is still an empty string');
ok(!defined SealTest::Data->cd_undef, 'an undef value is still undef');
ok(defined SealTest::Data->cd_empty,  'and an empty string is not undef');

# References come back pointing at the same thing, so in place modification
# through the accessor still works. Catalyst relies on this: MyApp->config->{x}
# = 1 is documented.
{
    my $h = SealTest::Data->cd_hash;
    is(ref $h, 'HASH', 'a hashref value is still a hashref');
    $h->{added} = 1;
    is(SealTest::Data->cd_hash->{added}, 1, 'and modifying it through the accessor sticks');
    is(SealTest::Data->cd_code->(), 'called', 'a coderef value is still callable');
    is(Scalar::Util::blessed(SealTest::Data->cd_object), 'SealTest::Data::Thing',
        'a blessed value keeps its class');
}

# An instance reads the same as the class.
{
    my $obj = SealTest::Data->new;
    is($obj->cd_string, 'a string', 'an instance invocant takes the fast path');
    is_deeply($obj->cd_hash, SealTest::Data->cd_hash, 'and gets the same value');
}

# Sealed means sealed, until something writes.
is(Catalyst::Seal::_is_sealed(SealTest::Data->can('cd_string')), 1,
    '_is_sealed reports a sealed accessor');
ok(!defined Catalyst::Seal::_is_sealed(SealTest::Data->can('attributes')),
    'and reports undef for something that is not one');

done_testing;
