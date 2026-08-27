use strict;
use warnings;
use Test::More;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

# Test::Kwalitee::Extra plans tests on import, so use require + a single
# explicit import call; a use followed by import replans and trips the
# Test::More plan guard.
eval { require Test::Kwalitee::Extra };
plan skip_all => 'Test::Kwalitee::Extra required' if $@;

# META.{json,yml} do not exist in a git checkout until make dist builds
# the tarball, so those indicators would fail for the wrong reason.
Test::Kwalitee::Extra->import(qw(
    !has_meta_yml
    !has_meta_json
));
