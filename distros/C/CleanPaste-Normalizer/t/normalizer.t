use strict;
use warnings;
use utf8;
use Test::More tests => 1;
use CleanPaste::Normalizer qw(normalize_pasted_text);

is normalize_pasted_text("Ａ\x{00a0}B\x{200b}\r\nsecond line  \rfinal\t "),
    "A B\nsecond line\nfinal",
    "normalizes pasted text";
