#!/usr/bin/env perl

use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";

# config/punk.yml carries relative paths (root/templates, root/static), so the
# process has to start from the application root for them to resolve. Doing it
# here rather than asking the operator to remember means `plackup app.psgi`
# works from anywhere.
#
# In BEGIN, because `use` below is itself compile-time: the application class
# loads its configuration as it compiles, which is before any statement out
# here would have run.
BEGIN {
    chdir $FindBin::Bin or die "cannot chdir to $FindBin::Bin: $!\n";
}

# Development fallback: run against the working copies before the
# distributions are installed - this one's blib and Punk's beside it.
BEGIN {
    my $dist = "$FindBin::Bin/../..";
    for my $b ($dist, "$dist/../Punk") {
        unshift @INC, "$b/blib/lib", "$b/blib/arch" if -d "$b/blib";
    }
}

use ApiKeyDemo;

ApiKeyDemo->to_app;
