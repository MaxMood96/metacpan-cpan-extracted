use strict;
use warnings;
use Test::More;

plan skip_all => 'run from the dist root' unless -f 'alienfile';

require './inc/Alien/TDLib/Version.pm';
require './inc/Alien/TDLib/Resolve.pm';

my $min = do { no warnings 'once'; $Alien::TDLib::Version::MIN_VERSION };
is $min, '1.8.66', 'floor is the oldest checked TDLib';
is $Alien::TDLib::Resolve::MIN_VERSION, $min, 'the resolver agrees on the floor';

is_deeply [Alien::TDLib::Version::parse('1.8.66')],  [1, 8, 66], 'parse dotted';
is_deeply [Alien::TDLib::Version::parse('1.8')],     [1, 8],     'parse short';
is_deeply [Alien::TDLib::Version::parse(' 1.8.66')], [1, 8, 66], 'leading space tolerated';
is_deeply [Alien::TDLib::Version::parse('1.8.66~git1')], [1, 8, 66], 'trailing suffix dropped';
is_deeply [Alien::TDLib::Version::parse('abc')],  [], 'garbage does not parse';
is_deeply [Alien::TDLib::Version::parse(undef)],  [], 'undef does not parse';
is_deeply [Alien::TDLib::Version::parse('')],     [], 'empty does not parse';

is Alien::TDLib::Version::compare('1.8.66', '1.8.66'), 0, 'equal versions';
is Alien::TDLib::Version::compare('1.8.66', '1.8.66.0'), 0, 'missing segments are zero';
is Alien::TDLib::Version::compare('1.8.66', '1.8'), 1, 'shorter version sorts lower';
is Alien::TDLib::Version::compare('1.8.9', '1.8.66'), -1, 'numeric, not string, segments';
is Alien::TDLib::Version::compare('1.8.66', '1.9.0'), -1, 'minor bump wins';
is Alien::TDLib::Version::compare('1.10.0', '1.9.0'), 1, 'two-digit minor';
is Alien::TDLib::Version::compare('2.0.0', '1.9.0'), 1, 'major bump';
ok !defined(Alien::TDLib::Version::compare('abc', '1.8.66')), 'unparseable gives undef';

my ($ok, $why);

($ok, $why) = Alien::TDLib::Version::check('1.8.66');
ok $ok, 'the floor itself is accepted';
like $why, qr/1\.8\.66 or newer/, 'acceptance says why';

($ok, $why) = Alien::TDLib::Version::check('1.8.99');
ok $ok, 'later 1.8.x accepted';

($ok, $why) = Alien::TDLib::Version::check('1.8.66.1');
ok $ok, 'four-segment 1.8.66.x accepted';

# no ceiling: the share install follows the newest release, so a newer system
# library must not be rejected just for being newer
($ok, $why) = Alien::TDLib::Version::check('1.9.0');
ok $ok, 'a new minor is accepted, not capped';

($ok, $why) = Alien::TDLib::Version::check('2.0.0');
ok $ok, 'a new major is accepted, not capped';

($ok, $why) = Alien::TDLib::Version::check('1.8.65');
ok !$ok, 'one patch below the floor rejected';
like $why, qr/older than the supported minimum/, 'rejection names the floor';

($ok, $why) = Alien::TDLib::Version::check('1.8.0');
ok !$ok, 'old 1.8.x rejected';

($ok, $why) = Alien::TDLib::Version::check('1.7.0');
ok !$ok, 'older minor rejected';

($ok, $why) = Alien::TDLib::Version::check(undef);
ok !$ok, 'unknown version rejected';
like $why, qr/could not be determined/, 'unknown version says so';

($ok, $why) = Alien::TDLib::Version::check('garbage');
ok !$ok, 'unparseable version rejected';

is Alien::TDLib::Version::range(), '1.8.66 or newer', 'range string';

done_testing;
