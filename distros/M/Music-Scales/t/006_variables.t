# -*- perl -*-

# t/006_variables.t - check that variables are exported

use Test::More tests => 9;

use_ok 'Music::Scales', qw(%original_modes %modes %abbrevs @scales);

my @got = keys %original_modes;
ok(@got);
is scalar(@got), 46, '%original_modes';
@got = keys %modes;
ok(@got);
is scalar(@got), 268, '%modes';
@got = keys %abbrevs;
ok(@got);
is scalar(@got), 268, '%abbrevs';
@got = @scales;
ok(@got);
is scalar(@got), 30, '@scales';

