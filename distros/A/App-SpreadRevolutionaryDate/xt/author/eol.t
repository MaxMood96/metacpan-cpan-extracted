use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/spread-revolutionary-date',
    'lib/App/SpreadRevolutionaryDate.pm',
    'lib/App/SpreadRevolutionaryDate/BlueskyLite.pm',
    'lib/App/SpreadRevolutionaryDate/Config.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/Gemini.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/PromptUser.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Calendar.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Locale.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Locale/en.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Locale/es.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Locale/fr.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/RevolutionaryDate/Locale/it.pm',
    'lib/App/SpreadRevolutionaryDate/MsgMaker/Telechat.pm',
    'lib/App/SpreadRevolutionaryDate/Target.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Bluesky.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Freenode.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Freenode/Bot.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Liberachat.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Liberachat/Bot.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Mastodon.pm',
    'lib/App/SpreadRevolutionaryDate/Target/Twitter.pm',
    't/00-compile.t',
    't/bluesky.t',
    't/command_line.t',
    't/config.t',
    't/locale.t',
    't/mastodon.t',
    't/new_target.t',
    't/objects.t',
    't/promptuser.t',
    't/telechat.t',
    't/twitter.t',
    't/wikipedia.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
