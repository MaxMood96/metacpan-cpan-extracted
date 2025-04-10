#!/usr/bin/perl

use utf8;
use strict;
use warnings;

use Test::More;

if ($^V lt v5.10) {
    plan skip_all => 'perl >= v5.10 needed';
}

use FindBin;
my $context = require "$FindBin::Bin/mem.pl";
plan skip_all => "no ps" unless check_ps();

package Test;

sub new {
    my ($class, $val) = @_;
    bless { val => $val }, $class
}

package main;

$context->eval('var DATA = []');
for (1..100000) {
    $context->eval('(function(data) { DATA.push(data); })')->(Test->new($_));
}

1 while !$context->idle_notification;

cmp_ok get_rss(), '<', 100_000, 'objects are not released';

done_testing;
