#!/usr/bin/perl

# $Id$

use strict;
use Test::More tests => 7;

use_ok('MDV::Distribconf::Build');

my $dconfb = MDV::Distribconf::Build->new();
ok($dconfb, "can create new MDV::Distribconf::Build object");

$dconfb->setvalue(undef, 'version', 'cauldron');
ok($dconfb->getvalue(undef, 'version') eq 'cauldron', "Can set global value");

$dconfb->setvalue('main');
ok(grep { $_ eq 'main' } $dconfb->listmedia, "Can add a media");

$dconfb->setvalue('main', 'property', 'media main');
ok($dconfb->getvalue('main', 'property') eq 'media main', "Can set global value");

$dconfb->delvalue('main', 'property');
ok(!$dconfb->getvalue('main', 'property'), "Can delete a media value");

$dconfb->delvalue('main');
ok(!grep { $_ eq 'main' } $dconfb->listmedia, "Can delete a media");
