use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/WWW/Spotify.pm',
    'lib/WWW/Spotify/Client.pm',
    'lib/WWW/Spotify/Endpoint.pm',
    'lib/WWW/Spotify/Response.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-spotify.t',
    't/02-live.t',
    't/03-ua.t',
    't/04-live-user-auth.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
