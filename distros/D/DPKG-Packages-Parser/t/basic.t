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

{
	my $r = $/;
	local $/ = undef;
	my $packages_as_string = <DATA>;
	local $/ = $r; # reset back
	open(my $fh, '<', \$packages_as_string) or die "cannot read __DATA__ from scalar\n";
	my $parser2 = DPKG::Packages::Parser->new(fh => $fh);
	$parser2->parse();
	my $perl = $parser2->get_package('perl');
	ok(defined($perl), 'we found a perl package');
	ok(@{$perl->{Recommends}} == 1, 'recommends has one element');
	ok($perl->{Recommends}->[0]->{name} eq 'netbase', 'netbase is recommended');
}

done_testing;

__DATA__
Package: perl
Version: 5.36.0-7+deb12u3
Installed-Size: 670
Maintainer: Niko Tyni <ntyni@debian.org>
Architecture: amd64
Replaces: perl-base (<< 5.36.0-2), perl-modules (<< 5.22.0~)
Provides: libansicolor-perl (= 5.01), libarchive-tar-perl (= 2.40), libattribute-handlers-perl (= 1.02), libautodie-perl (= 2.34), libcompress-raw-bzip2-perl (= 2.103), libcompress-raw-zlib-perl (= 2.105), libcompress-zlib-perl (= 2.106), libcpan-meta-perl (= 2.150010), libcpan-meta-requirements-perl (= 2.140), libcpan-meta-yaml-perl (= 0.018), libdigest-md5-perl (= 2.58), libdigest-perl (= 1.20), libdigest-sha-perl (= 6.02), libencode-perl (= 3.17), libexperimental-perl (= 0.028), libextutils-cbuilder-perl (= 0.280236), libextutils-command-perl (= 7.64), libextutils-install-perl (= 2.20), libextutils-parsexs-perl (= 3.450000), libfile-spec-perl (= 3.8400), libhttp-tiny-perl (= 0.080), libi18n-langtags-perl (= 0.45), libio-compress-base-perl (= 2.106), libio-compress-bzip2-perl (= 2.106), libio-compress-perl (= 2.106), libio-compress-zlib-perl (= 2.106), libio-zlib-perl (= 1.11), libjson-pp-perl (= 4.07000), liblocale-maketext-perl (= 1.31), liblocale-maketext-simple-perl (= 0.21.01), libmath-bigint-perl (= 1.999830), libmath-complex-perl (= 1.5902), libmime-base64-perl (= 3.16), libmodule-corelist-perl (= 5.20220520), libmodule-load-conditional-perl (= 0.74), libmodule-load-perl (= 0.36), libmodule-metadata-perl (= 1.000037), libnet-perl (= 1:3.14), libnet-ping-perl (= 2.74), libparams-check-perl (= 0.38), libparent-perl (= 0.238), libparse-cpan-meta-perl (= 2.150010), libperl-ostype-perl (= 1.010), libpod-escapes-perl (= 1.07), libpod-simple-perl (= 3.43), libstorable-perl (= 3.26), libsys-syslog-perl (= 0.36), libtest-harness-perl (= 3.44), libtest-simple-perl (= 1.302190), libtest-tester-perl (= 1.302190), libtest-use-ok-perl (= 1.302190), libtext-balanced-perl (= 2.04), libthread-queue-perl (= 3.14), libthreads-perl (= 2.27), libthreads-shared-perl (= 1.64), libtime-hires-perl (= 1.9770), libtime-local-perl (= 1.3000), libtime-piece-perl (= 1.3401), libunicode-collate-perl (= 1.31), libversion-perl (= 1:0.9929), libversion-requirements-perl, podlators-perl (= 4.14)
Depends: perl-base (= 5.36.0-7+deb12u3), perl-modules-5.36 (>= 5.36.0-7+deb12u3), libperl5.36 (= 5.36.0-7+deb12u3)
Pre-Depends: dpkg (>= 1.17.17)
Recommends: netbase
Suggests: perl-doc, libterm-readline-gnu-perl | libterm-readline-perl-perl, make, libtap-harness-archive-perl
Conflicts: libjson-pp-perl (<< 2.27200-2)
Breaks: apt-show-versions (<< 0.22.10), libdist-inkt-perl (<< 0.024-5), libmarc-charset-perl (<< 1.35-3), libperl-dev (<< 5.24.0~), perl-doc (<< 5.36.0-1), perl-modules-5.22, perl-modules-5.24, perl-modules-5.26 (<< 5.26.2-5)
Description: Larry Wall's Practical Extraction and Report Language
Multi-Arch: allowed
Homepage: http://dev.perl.org/perl5/
Description-md5: 603cb1e5fe66da8106c364f4e9b84082
Build-Essential: yes
Tag: devel::interpreter, devel::lang:perl, devel::library, implemented-in::c,
 implemented-in::perl, interface::commandline, role::devel-lib,
 role::metapackage, role::program
Section: perl
Priority: standard
Filename: pool/main/p/perl/perl_5.36.0-7+deb12u3_amd64.deb
Size: 238900
MD5sum: ecd2edf27d8e7a67795e81e1756de5f4
SHA256: afa50ec7d9b1a407cd0187dae033644ef13578d4f3792435e0c41b962ffec0c4

Package: libperl5.36
Source: perl
Version: 5.36.0-7+deb12u3
Installed-Size: 28864
Maintainer: Niko Tyni <ntyni@debian.org>
Architecture: amd64
Replaces: libarchive-tar-perl (<= 1.38-2), libcompress-raw-bzip2-perl (<< 2.103), libcompress-raw-zlib-perl (<< 2.105), libcompress-zlib-perl (<< 2.106), libdigest-md5-perl (<< 2.58), libdigest-sha-perl (<< 6.02), libencode-perl (<< 3.17), libio-compress-base-perl (<< 2.106), libio-compress-bzip2-perl (<< 2.106), libio-compress-perl (<< 2.106), libio-compress-zlib-perl (<< 2.106), libmime-base64-perl (<< 3.16), libmodule-corelist-perl (<< 2.14-2), libstorable-perl (<< 3.26), libsys-syslog-perl (<< 0.36), libthreads-perl (<< 2.27), libthreads-shared-perl (<< 1.64), libtime-hires-perl (<< 1.9770), libtime-piece-perl (<< 1.3401), perl (<< 5.22.0~), perl-base (<< 5.22.0~)
Depends: libbz2-1.0, libc6 (>= 2.35), libcrypt1 (>= 1:4.1.0), libdb5.3, libgdbm-compat4 (>= 1.18-3), libgdbm6 (>= 1.21), zlib1g (>= 1:1.2.2.3), perl-modules-5.36 (>= 5.36.0-7+deb12u3)
Suggests: sensible-utils
Breaks: libcompress-raw-bzip2-perl (<< 2.103), libcompress-raw-zlib-perl (<< 2.105), libcompress-zlib-perl (<< 2.106), libdigest-md5-perl (<< 2.58), libdigest-sha-perl (<< 6.02), libencode-perl (<< 3.17), libfilter-perl (<< 1.60), libio-compress-base-perl (<< 2.106), libio-compress-bzip2-perl (<< 2.106), libio-compress-perl (<< 2.106), libio-compress-zlib-perl (<< 2.106), libmime-base64-perl (<< 3.16), libstorable-perl (<< 3.26), libsys-syslog-perl (<< 0.36), libthreads-perl (<< 2.27), libthreads-shared-perl (<< 1.64), libtime-hires-perl (<< 1.9770), libtime-piece-perl (<< 1.3401)
Description: shared Perl library
Multi-Arch: same
Homepage: http://dev.perl.org/perl5/
Description-md5: 9f2b8bcf7a6d0534303f5c1c5a29866d
Tag: role::shared-lib
Section: libs
Priority: optional
Filename: pool/main/p/perl/libperl5.36_5.36.0-7+deb12u3_amd64.deb
Size: 4195924
MD5sum: 370d5291f477716a3c29192d61027184
SHA256: 591903643119c7e1735011369287976eccab1d79b1d2f210760e2138d0a3aa46

