#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require Catalyst::Seal::Accessors;
require Class::MOP;
require SealTest::Acc;

# A subclass that exists before sealing, so the parent's XSUB is inherited by
# something with its own slots.
{
    package SealTest::Acc::Child;
    use Moose;
    extends 'SealTest::Acc';
    __PACKAGE__->meta->make_immutable;
}

# ---------------------------------------------------------------- readers

my $before = SealTest::Acc->new(plain => 'p');
my %stock = map { $_ => $before->$_ } qw(plain withdef roone falsy);

my $sealed = Catalyst::Seal::Accessors::_seal_readers('SealTest::Acc');
cmp_ok($sealed, '>=', 5, 'the readers were sealed') or diag "sealed $sealed";

is(Catalyst::Seal::_is_sealed(SealTest::Acc->can('plain')), 1,
    '_is_sealed recognises a sealed reader');

{
    my $o = SealTest::Acc->new(plain => 'p');
    is($o->plain,   $stock{plain},   'a plain reader agrees with stock');
    is($o->withdef, $stock{withdef}, 'a reader with a default agrees');
    is($o->falsy,   $stock{falsy},   'an empty string is still an empty string');
    is(ref $o->roone, 'ARRAY',       'a ro reader still returns its default');

    # An attribute never given a value reads as undef, not as an error.
    my $bare = SealTest::Acc->new;
    ok(!defined $bare->plain, 'an unset attribute reads as undef');
}

# A rw accessor is one method that both reads and writes. The XSUB only
# answers the read.
{
    my $o = SealTest::Acc->new(plain => 'p');
    is($o->plain('q'), 'q', 'writing through the sealed accessor returns the value');
    is($o->plain, 'q', 'and the new value reads back');
}

# ------------------------------------------------------------------- lazy

{
    local $SealTest::Acc::BUILDS = 0;
    my $o = SealTest::Acc->new;

    ok(!$o->has_lazyone, 'the predicate is false before the first read');
    is($o->lazyone, 'built', 'the lazy attribute builds on first read');
    ok($o->has_lazyone, 'and the predicate is true afterwards');

    $o->lazyone for 1 .. 50;
    is($SealTest::Acc::BUILDS, 1, 'the builder ran exactly once across 51 reads');
}

# A lazy attribute given a value at construction never builds.
{
    local $SealTest::Acc::BUILDS = 0;
    my $o = SealTest::Acc->new(lazyone => 'given');
    is($o->lazyone, 'given', 'a constructed value wins');
    is($SealTest::Acc::BUILDS, 0, 'and the builder never ran');
}

# --------------------------------------------------------------- invocant

{
    # A subclass instance is not the class we sealed, so it delegates. It must
    # still see its own slot, not the parent's.
    my $child = SealTest::Acc::Child->new(plain => 'child value');
    is($child->plain, 'child value', 'a subclass instance reads its own slot');

    my $parent = SealTest::Acc->new(plain => 'parent value');
    is($parent->plain, 'parent value', 'and the parent is unaffected');
}

{
    # A class method call has no slot to read. Stock Moose dies; so must we,
    # and with the same kind of error rather than a segfault or an undef.
    my $stock_err = do { local $@; eval { SealTest::Acc::Child->new; SealTest::Acc->withdef }; $@ };
    ok($stock_err, 'a class method call on a reader still dies');
    like($stock_err, qr/without a blessed reference|Can't use string|HASH/i,
        'and dies about the invocant') or diag $stock_err;
}

# --------------------------------------------------------------- delegators

{
    require TestApp;
    is(TestApp->can('req'), TestApp->can('request'),
        'req was aliased straight to request');
    is(TestApp->can('res'), TestApp->can('response'),
        'res was aliased straight to response');
}

# ------------------------------------------------------------------ config

{
    my $config = TestApp->config;
    is(ref $config, 'HASH', 'config still returns a hashref');
    is($config->{name}, 'TestApp', 'with the right contents');
    is(Catalyst::Seal::_is_sealed(TestApp->can('config')), 1, 'and is a sealed constant');

    # Documented behaviour: MyApp->config->{foo} = 'bar' works, because the
    # constant is the same reference the stock chain returned.
    $config->{sealed_probe} = 1;
    is(TestApp->config->{sealed_probe}, 1, 'in place modification still works');

    # And Catalyst's own rule survives: a write after setup croaks. That comes
    # from the around modifier the slow path delegates to, which is the reason
    # the slow path exists.
    my $err = do { local $@; eval { TestApp->config(extra => 1) }; $@ };
    like($err, qr/Setting config after setup/,
        'writing config after setup still croaks') or diag $err;
}

# The application still answers.
{
    require SealTest;
    my $res = SealTest::response(TestApp->psgi_app);
    is($res->[0], 200, 'the sealed application answers');
    is(join('', @{ $res->[2] }), 'hello', 'with the right body');
}

done_testing;
