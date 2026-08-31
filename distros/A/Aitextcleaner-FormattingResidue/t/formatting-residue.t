use strict;
use warnings;
use Test::More;
use lib 'lib';
use Aitextcleaner::FormattingResidue qw(clean_formatting_residue);

is(
    clean_formatting_residue('<p>Hello <span>world</span>…</p><div>Next line</div>'),
    "Hello world...\n\nNext line",
    'cleans copied formatting residue',
);

done_testing;
