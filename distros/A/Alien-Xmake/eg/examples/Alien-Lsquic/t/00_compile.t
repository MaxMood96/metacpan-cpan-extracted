use v5.40;
use blib;
use Test2::V0;
use Alien::lsquic;
#
my $lsquic = Alien::lsquic->new;
isa_ok $lsquic, ['Alien::lsquic'],      'isa Alien::lsquic';
isa_ok $lsquic, ['Alien::Xrepo::Base'], 'isa Alien::Xrepo::Base';
is $lsquic->package_name, 'lsquic', 'package_name is lsquic';
#
done_testing;
