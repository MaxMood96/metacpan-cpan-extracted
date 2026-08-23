use strict;
use warnings;
use Test::More;

# Explicitly count our baseline verification steps
plan tests => 3;

# 1. Verify the root namespace compiles cleanly
use_ok('Uniform') or bail_out("Could not compile Uniform base namespace!");

# 2. Verify version flag exposure matches expected formatting
my $version = $Uniform::VERSION;
ok(defined $version && $version =~ /^\d+\.\d+$/, "Package exposes a valid version string ($version)");

# 3. Verify the utility library compiles and loads
use_ok('Uniform::Utils') or bail_out("Could not compile Uniform::Utils utility module!");

diag("Testing Uniform $Uniform::VERSION, Perl $], $^X");
