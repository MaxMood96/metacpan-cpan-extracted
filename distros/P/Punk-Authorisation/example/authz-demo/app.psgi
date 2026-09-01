#!/usr/bin/env perl
# A full Punk::Plugin::Authorisation application: three people on three rungs
# of one ladder, three documents, and one file of rules deciding who may do
# what to which row.
#
#     plackup -s Hyperman app.psgi
#
# Everything is in memory: one restart and every document, grant and session
# is back where it started.

use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";

# config/punk.yml carries relative paths (root/templates, root/static), so the
# process has to start from the application root for them to resolve. In
# BEGIN, because `use` below is itself compile-time.
BEGIN {
    chdir $FindBin::Bin or die "cannot chdir to $FindBin::Bin: $!\n";
}

# Development fallback: run against the working copies before the dists are
# installed - this dist's own blib first, so a stale installed
# Punk/Plugin/Authorisation.pm from before this distribution existed cannot
# win and quietly install no `rule` keyword.
BEGIN {
    my $dist = "$FindBin::Bin/../..";
    for my $b ("$dist/blib", map { "$dist/../$_/blib" } 'Punk') {
        unshift @INC, "$b/lib", "$b/arch" if -d $b;
    }
}

use AuthzDemo;

AuthzDemo->to_app;
