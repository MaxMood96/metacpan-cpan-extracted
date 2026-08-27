#!/usr/bin/env perl
# Compress one asset, for the make rule that keeps a precompressed sibling in
# step with the file it came from.
#
# A SCRIPT RATHER THAN A -e ONE-LINER because the rule runs under whatever
# make and shell the platform has, and quoting a Perl one-liner through nmake
# and cmd.exe is its own small disaster.
#
# Time => 0 because a gzip member stores an mtime: without it the output
# differs on every run, so the file is rewritten whenever make is run and
# every rebuild looks like a change.
use 5.010;
use strict;
use warnings;

my ($src, $dst) = @ARGV;
die "usage: $0 <source> <destination>\n" unless defined $src && defined $dst;

unless (eval { require IO::Compress::Gzip; 1 }) {
    # Not fatal. Without a sibling the plugin serves the identity file, which
    # is correct and merely larger - and a build must not fail over an
    # optimisation.
    warn "gzip-asset: IO::Compress::Gzip unavailable, skipping $src\n";
    exit 0;
}

# `once` is off for the error variable: the module is loaded by require, so
# the name is not declared at compile time and mentioning it exactly once
# looks like a typo to the very check that exists to catch typos.
{
    no warnings 'once';
    IO::Compress::Gzip::gzip($src => $dst, Level => 9, Time => 0)
        or die "gzip-asset: $src -> $dst: $IO::Compress::Gzip::GzipError\n";
}

exit 0;
