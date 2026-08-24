#!perl

use strict;
use Test::More tests => 1;
my $do_mvr;
my $LOADED;
BEGIN {
        $LOADED = eval { require CPAN::Testers::ParseReport; 1 };
        ok $LOADED, "LOADED=$LOADED";
        $do_mvr = eval { require Module::Versions::Report; 1 };
}
eval "use Test::CPAN::Meta";
eval "use File::Spec";
eval "use List::AllUtils qw(sum max)";
eval "use utf8";
eval "use Time::HiRes qw(time)";
if ($do_mvr) {
    diag(Module::Versions::Report->report);
} else {
    diag( "Testing CPAN::Testers::ParseReport LOADED='$LOADED' $CPAN::Testers::ParseReport::VERSION, Perl $], $^X" );
}
