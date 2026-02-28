use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT like require_ok ) ], tests => 2;
use Test::API import => [ qw( public_ok ) ];
use Test::Fatal qw( exception );

my $class;

BEGIN {
  $class = 'Version::Semantic';
  require_ok $class or BAIL_OUT "Cannot load class '$class'!"
}

public_ok $class,
  qw( new parse prefix major minor patch pre_release build version_core has_prefix has_pre_release has_build increment compare_to to_string semver_re )
