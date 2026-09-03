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

# A write after sealing has to work, and it has to keep working. Catalyst does
# this itself: prepare writes context_class and _finalized_psgi_app writes
# _psgi_app, both long after setup_finalize.

Catalyst::Seal::ClassData::_seal_class('SealTest::Data');

is(SealTest::Data->cd_writable, 'before', 'sealed value reads back');
is(Catalyst::Seal::_is_sealed(SealTest::Data->can('cd_writable')), 1, 'and is sealed');

# The write itself returns what the stock accessor returns: the value written.
my $returned = SealTest::Data->cd_writable('after');
is($returned, 'after', 'the write returns the value written');

is(SealTest::Data->cd_writable, 'after', 'and the new value is what reads back');
# Once unsealed, the glob no longer holds our XSUB at all, so _is_sealed
# reports undef rather than 0. Either way it is not sealed.
ok(!Catalyst::Seal::_is_sealed(SealTest::Data->can('cd_writable')),
    'the accessor unsealed itself');

# Both halves of the pair unseal together. Two independent slots would leave
# the alias returning the stale constant, which is the whole reason they share
# one.
is(SealTest::Data->_cd_writable_accessor, 'after',
    'the _accessor alias sees the new value too');

# A second write still works, through the restored accessor this time.
SealTest::Data->cd_writable('again');
is(SealTest::Data->cd_writable, 'again', 'a second write works');
is(SealTest::Data->_cd_writable_accessor, 'again', 'and the alias agrees');

# Unsealing one attribute leaves the others alone.
is(Catalyst::Seal::_is_sealed(SealTest::Data->can('cd_string')), 1,
    'an unrelated attribute is still sealed');
is(SealTest::Data->cd_string, 'a string', 'and still reads correctly');

# Writing undef, which the stock accessor stores but then cannot distinguish
# from absent on the way out.
{
    SealTest::Data->cd_string(undef);
    my @list = SealTest::Data->cd_string;
    is(scalar @list, 0, 'a value written as undef reads back as an empty list');
    my $scalar = SealTest::Data->cd_string;
    ok(!defined $scalar, 'and as undef in scalar context');
}

# Writing to a class whose parent is sealed does not disturb the parent.
{
    package SealTest::Data::Writer;
    use Moose;
    extends 'SealTest::Data';
    __PACKAGE__->meta->make_immutable;
}
{
    SealTest::Data->cd_zero(0);   # make sure the parent has a known value
    Catalyst::Seal::ClassData::_seal_class('SealTest::Data::Writer');
    SealTest::Data::Writer->cd_zero(99);
    is(SealTest::Data::Writer->cd_zero, 99, 'the child took the write');
    is(SealTest::Data->cd_zero, 0, 'and the parent kept its own value');
}

done_testing;
