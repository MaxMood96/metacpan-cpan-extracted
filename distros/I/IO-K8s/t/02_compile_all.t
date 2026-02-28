#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Find;

my @modules;
find(sub {
    return unless /\.pm$/;
    my $path = $File::Find::name;
    $path =~ s{^lib/}{};
    $path =~ s{/}{::}g;
    $path =~ s{\.pm$}{};
    push @modules, $path;
}, 'lib');

plan tests => scalar @modules;

for my $mod (sort @modules) {
    require_ok($mod);
}
