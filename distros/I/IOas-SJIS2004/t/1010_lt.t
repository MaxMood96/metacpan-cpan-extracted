######################################################################
#
# 1010_lt.t
#
# Copyright (c) 2019 INABA Hitoshi <ina@cpan.org> in a CPAN
######################################################################

# This file is encoded in UTF-8.
die "This file is not encoded in UTF-8.\n" if 'あ' ne "\xe3\x81\x82";
die "This script is for perl only. You are using $^X.\n" if $^X =~ /jperl/i;

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use IOas::SJIS2004;
use vars qw(@test);

@test = (
# 1
    sub { not IOas::SJIS2004::lt('Ｂ','Ａ')       },
    sub { not IOas::SJIS2004::lt('Ｂ','Ｂ')       },
    sub {     IOas::SJIS2004::lt('Ｂ','Ｃ')       },
    sub { not IOas::SJIS2004::lt('２２','２')     },
    sub { not IOas::SJIS2004::lt('２２','２２')   },
    sub {     IOas::SJIS2004::lt('２２','２２２') },
    sub { not IOas::SJIS2004::lt('２２','１１０') },
    sub {     IOas::SJIS2004::lt('２２','３３０') },
    sub { not IOas::SJIS2004::lt('２２','１')     },
    sub {     IOas::SJIS2004::lt('２２','３')     },
#
);

$|=1; print "1..",scalar(@test),"\n"; my $testno=1; sub ok { print $_[0]?'ok ':'not ok ',$testno++,$_[1]?" - $_[1]\n":"\n" } ok($_->()) for @test;

__END__
