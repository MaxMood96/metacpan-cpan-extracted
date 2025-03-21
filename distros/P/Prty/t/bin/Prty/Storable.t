#!/usr/bin/env perl

package Prty::Storable::Test;
use base qw/Prty::Test::Class/;

use strict;
use warnings;
use v5.10.0;

# -----------------------------------------------------------------------------

sub test_loadClass : Init(1) {
    shift->useOk('Prty::Storable');
}

# -----------------------------------------------------------------------------

sub test_unitTest : Test(6) {
    my $self = shift;

    my $ser = Prty::Storable->freeze({a=>1,b=>2,c=>3});
    my $ref = Prty::Storable->thaw($ser);
    my @keys = sort keys %$ref;
    $self->isDeeply(\@keys,[qw/a b c/]);
    $self->is($ref->{'a'},1);
    $self->is($ref->{'b'},2);
    $self->is($ref->{'c'},3);

    my $clone = Prty::Storable->clone($ref);
    $self->isnt($clone,$ref);
    $self->isDeeply($clone,$ref);
}

# -----------------------------------------------------------------------------

package main;
Prty::Storable::Test->runTests;

# eof
