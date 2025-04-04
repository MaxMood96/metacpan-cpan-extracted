use strict;
use warnings;
use Test::More;
use lib qw(./lib ./blib/lib);
require './t/600-lhost-code';

my $enginename = 'EZweb';
my $enginetest = Sisimai::Lhost::Code->makeinquiry;
my $isexpected = {
    # INDEX => [['D.S.N.', 'replycode', 'REASON', 'hardbounce'], [...]]
    '01' => [['5.0.910', '',    'filtered',        0]],
    '02' => [['5.0.0',   '550', 'suspend',         0]],
    '03' => [['5.0.921', '',    'suspend',         0]],
    '04' => [['5.0.911', '550', 'userunknown',     1]],
    '05' => [['5.0.947', '',    'expired',         0]],
    '07' => [['5.0.911', '550', 'userunknown',     1]],
    '08' => [['5.0.971', '550', 'blocked',         0]],
};

$enginetest->($enginename, $isexpected);
done_testing;

