
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/Crypt/EAMessage.pm',
    'lib/Crypt/EAMessage/Keygen.pm',
    't/00-load.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-use.t',
    't/02-key.t',
    't/03-encrypt-decrypt.t',
    't/04-backwards-compatability.t',
    't/05-calling.t',
    't/06-invalid-encodings.t',
    't/07-keygen.t',
    't/08-class.t',
    't/author-critic.t',
    't/author-eol.t',
    't/author-no-tabs.t',
    't/author-pod-syntax.t',
    't/author-test-version.t',
    't/create.pl',
    't/data/perlcriticrc',
    't/release-changes_has_content.t',
    't/release-kwalitee.t',
    't/release-trailing-space.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
