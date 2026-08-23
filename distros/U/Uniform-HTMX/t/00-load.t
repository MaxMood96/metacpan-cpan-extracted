use strict;
use warnings;
use Test::More;

# Explicitly count our validation steps
plan tests => 2;

# 1. Test if the package compiles successfully
use_ok('Uniform::HTMX') or bail_out("Could not compile Uniform::HTMX core module!");

# 2. Verify version flag exists and matches expected format
my $version = $Uniform::HTMX::VERSION;
ok(defined $version && $version =~ /^\d+\.\d+$/, "Package exposes a valid version string ($version)");

diag("Testing Uniform::HTMX $Uniform::HTMX::VERSION, Perl $], $^X");
