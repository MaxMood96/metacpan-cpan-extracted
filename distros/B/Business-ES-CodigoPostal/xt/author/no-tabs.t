use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Business/ES/CodigoPostal.pm',
    't/00-compile.t',
    't/basic.t',
    't/codigos.t',
    't/function.t',
    't/pod.t'
);

notabs_ok($_) foreach @files;
done_testing;
