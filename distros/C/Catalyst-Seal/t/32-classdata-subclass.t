#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require Catalyst::Seal::ClassData;
require SealTest::Data;

# The accessors live in the base classes and are shared by every application in
# the process, so a constant cannot be installed over them. It goes into each
# concrete class, where it shadows the inherited closure.
#
# That shadowing is the risk this file is about. A subclass created after
# sealing inherits our XSUB but not our answer, and must not be told the
# parent's value in place of its own.

SealTest::Data->cd_string('the parent value');
SealTest::Data->cd_inherited('inherited from the parent');
Catalyst::Seal::ClassData::_seal_class('SealTest::Data');

is(SealTest::Data->cd_string, 'the parent value', 'the parent is sealed and correct');

# A subclass that appears afterwards, with class data of its own.
{
    package SealTest::Data::Late;
    use Moose;
    extends 'SealTest::Data';
    __PACKAGE__->meta->make_immutable;
}
SealTest::Data::Late->cd_string('the child value');

is(SealTest::Data::Late->cd_string, 'the child value',
    'a subclass created after sealing gets its own value, not the parent constant');
is(SealTest::Data::Late->_cd_string_accessor, 'the child value',
    'and so does the _accessor alias');
is(SealTest::Data->cd_string, 'the parent value',
    'and the parent is unaffected');

# A subclass with no value of its own still inherits the parent's.
{
    package SealTest::Data::Quiet;
    use Moose;
    extends 'SealTest::Data';
    __PACKAGE__->meta->make_immutable;
}
is(SealTest::Data::Quiet->cd_inherited, 'inherited from the parent',
    'a subclass with no value of its own still inherits');

# An instance of the subclass takes the same path as the class.
{
    my $obj = SealTest::Data::Late->new;
    is($obj->cd_string, 'the child value', 'an instance of the subclass agrees');
}

# The parent stayed sealed through all of that: a subclass read delegates, it
# does not unseal.
is(Catalyst::Seal::_is_sealed(SealTest::Data->can('cd_string')), 1,
    'reading through a subclass did not unseal the parent');

# An invocant that is neither the sealed class nor an object of it.
{
    my $accessor = SealTest::Data->can('cd_string');
    my $bare = bless {}, 'SealTest::Data::Unrelated';
    my $got = eval { $bare->$accessor };
    ok(!$@, 'an unrelated invocant does not croak') or diag $@;
}

# List and scalar context on the fast path.
{
    my @list = SealTest::Data->cd_string;
    is(scalar @list, 1, 'one value in list context');
    is($list[0], 'the parent value', 'and it is the right one');
    my $scalar = SealTest::Data->cd_string;
    is($scalar, 'the parent value', 'scalar context agrees');
}

done_testing;
