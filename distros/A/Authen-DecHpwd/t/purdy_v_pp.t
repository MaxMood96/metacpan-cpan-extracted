use warnings;
use strict;

do "./t/setup_pp.pl" or die $@ || $!;
do "./t/purdy_v.t" or die $@ || $!;

1;
