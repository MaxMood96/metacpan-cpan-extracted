use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/WWW/Spotify.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-spotify.t',
    't/02-live.t',
    't/03-ua.t',
    't/04-send-request.t',
    't/05-oauth-user.t',
    't/06-methods-mocked.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
