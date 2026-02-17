#!/usr/bin/env perl

package Quiq::KositValidator::Test;
use base qw/Quiq::Test::Class/;

use v5.10;
use strict;
use warnings;

use Quiq::Path;
use Quiq::Test::Class;

# -----------------------------------------------------------------------------

sub test_loadClass : Init(1) {
    shift->useOk('Quiq::KositValidator');
}

# -----------------------------------------------------------------------------

sub test_unitTest: Test(1) {
    my $self = shift;

    my $p = Quiq::Path->new;

    my $validatorDir = '~/sys/opt/kosit-validator';
    if (!$p->exists($validatorDir)) {
        $self->skipAll('Validator directory doeas not exist');
        return;
    }

    my $kvl = Quiq::KositValidator->new($validatorDir);
    $self->is(ref($kvl),'Quiq::KositValidator');

    # my $xmlFile = Quiq::Test::Class->testPath(
    #     'quiq/test/data/mustang/174341665800.xml');
    # 
    # my $status = $mus->validate($xmlFile);
    # $self->is($status,0);
    # 
    # (my $pdfFile = $xmlFile) =~ s/xml$/pdf/;
    # $mus->visualize($xmlFile,$pdfFile);
    # $self->is(-e $pdfFile,1);
}

# -----------------------------------------------------------------------------

package main;
Quiq::KositValidator::Test->runTests;

# eof
