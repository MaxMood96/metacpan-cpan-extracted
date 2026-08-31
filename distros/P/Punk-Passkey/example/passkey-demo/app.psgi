#!/usr/bin/env perl
# A passkey-only Punk application.
#
#     plackup app.psgi
#     # then open http://localhost:5000/
#
# The origin matters: a passkey is bound to one, and WebAuthn needs a
# secure context. http://localhost is exempt from the https rule, which
# is why the default works. On another port or host, set the origin to
# match what is in the address bar:
#
#     PASSKEY_DEMO_ORIGIN=http://localhost:8080 plackup -p 8080 app.psgi

use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";

# config/punk.yml carries relative paths (root/templates, root/static), so
# the process has to start from the application root for them to resolve.
# In BEGIN, because `use` below is itself compile-time: the application
# class loads its configuration as it compiles.
BEGIN {
    chdir $FindBin::Bin or die "cannot chdir to $FindBin::Bin: $!\n";
}

# Development fallback: run against the working copy before the dist is
# installed. Harmless once it is.
BEGIN {
    my $dist = "$FindBin::Bin/../..";
    for my $b ($dist, map { "$dist/../$_" } 'Crypt-JWS', 'File-Raw-JSON') {
        unshift @INC, "$b/blib/lib", "$b/blib/arch" if -d "$b/blib";
    }
}

use PasskeyDemo;

PasskeyDemo->to_app;
