#!/usr/bin/env perl
# A full Punk::Plugin::TOTP application: sign in with a password, enrol a
# phone, and from then on the plugin stands between the password and the
# session. Stencil templates, controllers, and config/punk.yml - the
# `punk new` layout - where example/demo.psgi is one file driving the
# engine by hand.
#
#     plackup -s Hyperman app.psgi
#
# Everything is in memory: one user, password "punk", reborn on every
# restart.

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

# Development fallback: run against the working copies before the dists
# are installed - this dist's own blib, and its siblings (see t/sibling.pl
# in the dist for the reasoning).
BEGIN {
    my $dist = "$FindBin::Bin/../..";
    for my $b ("$dist/blib", map { "$dist/../$_/blib" }
               'File-Raw-Hash', 'QR-Code', 'Punk-TOTP') {
        unshift @INC, "$b/lib", "$b/arch" if -d $b;
    }
}

use TOTPDemo;

TOTPDemo->to_app;
