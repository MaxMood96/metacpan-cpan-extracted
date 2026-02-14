use strict;
use Test::More;
use DPKG::Packages::Parser;

my $parser1 = DPKG::Packages::Parser->new(file => "t/Packages");
ok($parser1->file() eq 't/Packages');
$parser1->parse();
my $pkg = $parser1->get_package('2048-qt');
ok($pkg->{Package} eq '2048-qt');
ok($pkg->{Source} eq '2048-qt (0.1.6-2)');
ok($pkg->{Version} eq '0.1.6-2+b2');
ok($pkg->{"Installed-Size"} == 3817);
ok($pkg->{Maintainer} eq 'Alejandro Garrido Mota <alejandro@debian.org>');
ok($pkg->{Architecture} eq 'amd64');
ok($pkg->{Description} eq 'mathematics based puzzle game');
ok($pkg->{Homepage} eq 'https://github.com/xiaoyong/2048-Qt');
ok($pkg->{"Description-md5"} eq '0f25c2ca95ceff4500fde9f651d74f2e');
ok(@{$pkg->{Tag}} == 7, 'There are 7 tags');
ok($pkg->{"Tag"}[0] eq 'game::puzzle');
ok($pkg->{"Tag"}[6] eq 'x11::application');
ok($pkg->{"Section"} eq 'games');
ok($pkg->{"Priority"} eq 'optional');
ok($pkg->{"Filename"} eq 'pool/main/2/2048-qt/2048-qt_0.1.6-2+b2_amd64.deb');
ok($pkg->{"Size"} == 1393256);
ok($pkg->{"MD5sum"} eq '38918b12a0ca4066403019b69e50adde');
ok($pkg->{"SHA256"} eq 'a7e575e574629d6151f27507b4c9b49bef3ad46ffaa08321ea487568c0153b65');
ok(@{$pkg->{Depends}} == 8);
# Test parsing of version information in Depends list
my $depends_libc = $pkg->{Depends}->[0];
ok($depends_libc->{name} eq 'libc6', 'name is libc6');
ok($depends_libc->{op} eq '>=', 'operator is >=');
ok($depends_libc->{version} eq '2.4', 'version is 2.4');

# Test the OR functionality
$pkg = $parser1->get_package('0ad-data-common');
ok(@{$pkg->{Depends}} == 3, 'There are 3 dependencies');
my @depends_items = @{$pkg->{Depends}->[0]};
ok(@depends_items == 2, 'It is either fonts-dejavu-core OR ttf-dejavu-core');
ok($depends_items[0]->{name} eq 'fonts-dejavu-core');
ok($depends_items[1]->{name} eq 'ttf-dejavu-core');

# Test the parsing when you just want a list of fields and not everything.
$parser1->parse('Size', 'MD5sum');
my $zeroAD = $parser1->get_package('0ad');
ok($zeroAD->{Package} eq '0ad');
ok($zeroAD->{Size} == 7891488);
ok($zeroAD->{MD5sum} eq '4d471183a39a3a11d00cd35bf9f6803d');

# Test the package string parser
my $e = $parser1->_parse_package_str('0ad-data (>= 0.0.026)');
ok($e->{name} eq '0ad-data');
ok($e->{op} eq '>=');
ok($e->{version} eq '0.0.026');

$e = $parser1->_parse_package_str('python3:any');
ok($e->{name} eq 'python3');
ok(!defined($e->{version}));
ok($e->{arch} eq 'any');

$e = $parser1->_parse_package_str('lmms-vst-server:i386 (>= 1.2.2+dfsg1-6)');
ok($e->{name} eq 'lmms-vst-server');
ok($e->{arch} eq 'i386');
ok($e->{op} eq '>=');
ok($e->{version} eq '1.2.2+dfsg1-6');

done_testing;
