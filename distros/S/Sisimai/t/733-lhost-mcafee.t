use strict;
use warnings;
use Test::More;
use lib qw(./lib ./blib/lib);
require './t/600-lhost-code';

my $enginename = 'McAfee';
my $enginetest = Sisimai::Lhost::Code->makeinquiry;
my $isexpected = {
    # INDEX => [['D.S.N.', 'replycode', 'REASON', 'hardbounce'], [...]]
    '01' => [['5.0.910', '550', 'filtered',        0]],
    '02' => [['5.1.1',   '550', 'userunknown',     1]],
    '03' => [['5.1.1',   '550', 'userunknown',     1]],
    '04' => [['5.0.910', '550', 'filtered',        0]],
    '05' => [['5.0.910', '550', 'filtered',        0]],
};

$enginetest->($enginename, $isexpected);
done_testing;

