#!/usr/bin/perl
use 5.016;
use strict;

use Test::More;

use File::Path qw(remove_tree);
use File::Spec;
use File::Temp qw(tempdir tempfile);

use EBook::Ishmael;
# For CAN_TEST
use EBook::Ishmael::EBook::CB7;
use EBook::Ishmael::EBook::CBR;
use EBook::Ishmael::EBook::CHM;
use EBook::Ishmael::EBook::PDF;
use EBook::Ishmael::TextBrowserDump;

# The following formats depend on system utilities to be installed to be
# processed correctly. Some systems' versions of the utilities may not work
# as intended and cause test failures, so give the user the option to disable
# tests for those formats.
my $TEST_PDF = $ENV{TEST_PDF} // $EBook::Ishmael::EBook::PDF::CAN_TEST;
my $TEST_CBR = $ENV{TEST_CBR} // $EBook::Ishmael::EBook::CBR::CAN_TEST;
my $TEST_CB7 = $ENV{TEST_CB7} // $EBook::Ishmael::EBook::CB7::CAN_TEST;
my $TEST_CHM = $ENV{TEST_CHM} // $EBook::Ishmael::EBook::CHM::CAN_TEST;

my @FILES = map { File::Spec->catfile(qw(t data), $_) } qw(
    gpl3.epub gpl3.fb2 gpl3.html gpl3.mobi gpl3.pdb gpl3.txt gpl3.xhtml
    gpl3.ztxt gpl3.pdf gpl3.cbr  gpl3.cbz  gpl3.cb7 web2help.chm gpl3.azw3
    gpl3.zip
);

my %IMAGES = (
    epub  => 1,
    fb2   => 1,
    html  => 0,
    mobi  => 2,
    pdb   => 0,
    txt   => 0,
    xhtml => 0,
    ztxt  => 0,
    pdf   => 0,
    cbr   => 28,
    cbz   => 28,
    cb7   => 28,
    chm   => 2,
    azw3  => 2,
    zip   => 1,
);

my %CUSTOM_ENC = map { $_ => 1 } qw(
    html pdb txt ztxt zip
);

my $tmpout = do {
    my ($fh, $tmp) = tempfile(UNLINK => 1);
    close $fh;
    $tmp;
};

sub new_ishmael {

    local @ARGV = ('-N', @_);

    return EBook::Ishmael->init;

}

for my $f (@FILES) { SKIP: {

    my $ishmael;

    my ($file) = $f =~ /\.(.+)$/;

    if (!$TEST_PDF and $file eq 'pdf') {
        skip "TEST_PDF set to 0 or poppler utils not installed", 10;
    }

    if (!$TEST_CBR and $file eq 'cbr') {
        skip "TEST_CBR set to 0 or unrar not installed", 10;
    }

    if (!$TEST_CB7 and $file eq 'cb7') {
        skip "TEST_CB7 set to 0 or 7z not installed", 10;
    }

    if (!$TEST_CHM and $file eq 'chm') {
        skip "TEST_CHM set to 0 or chmlib not installed", 10;
    }

    $ishmael = new_ishmael('-H', $f, $tmpout);
    ok($ishmael->run, "-H w/ $file ok");

    $ishmael = new_ishmael(qw(-H -e cp1252), $f, $tmpout);
    ok($ishmael->run, "cp1252 -H w/ $file ok");

    $ishmael = new_ishmael('-i', $f);
    ok($ishmael->run, "-i w/ $file ok");

    $ishmael = new_ishmael(qw(-m ishmael), $f, $tmpout);
    ok($ishmael->run, "-m ishmael w/ $file ok");

    $ishmael = new_ishmael(qw(-m json), $f, $tmpout);
    ok($ishmael->run, "-m json w/ $file ok");

    $ishmael = new_ishmael(qw(-m xml), $f, $tmpout);
    ok($ishmael->run, "-m xml w/ $file ok");

    $ishmael = new_ishmael('-r', $f, $tmpout);
    ok($ishmael->run, "-r w/ $file ok");

    $ishmael = new_ishmael(qw(-r -e cp1252), $f, $tmpout);
    ok($ishmael->run, "cp1252 -r w/ $file ok");

    if (exists $CUSTOM_ENC{ $file }) {
        $ishmael = new_ishmael(qw(-r -I UTF-8), $f, $tmpout);
        ok($ishmael->run, "-I w/ $file ok");
    }

    $ishmael = new_ishmael('-c', $f, $tmpout);
    ok($ishmael->run, "-c w/ $file ok");

    my $tmp = tempdir(CLEANUP => 1);

    $ishmael = new_ishmael('-g', $f, $tmp);
    ok($ishmael->run, "-g w/ $file ok");

    my @glob = glob "$tmp/*";

    is(
        scalar @glob,
        $IMAGES{ $file },
        "-g dump count w/ $file ok"
    );

    remove_tree($tmp, { safe => 1 });

}}

done_testing();
