use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/Syntax/Feature/Junction.pm',
    'lib/Syntax/Keyword/Junction.pm',
    'lib/Syntax/Keyword/Junction/All.pm',
    'lib/Syntax/Keyword/Junction/Any.pm',
    'lib/Syntax/Keyword/Junction/Base.pm',
    'lib/Syntax/Keyword/Junction/None.pm',
    'lib/Syntax/Keyword/Junction/One.pm',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01_use.t',
    't/all.t',
    't/any.t',
    't/import_tags.t',
    't/join.t',
    't/no_import.t',
    't/none.t',
    't/one.t',
    't/smartmatch.t',
    't/syntax.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
