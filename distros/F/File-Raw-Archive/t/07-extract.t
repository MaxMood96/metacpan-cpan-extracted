#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Raw::Archive;

my $dir = tempdir(CLEANUP => 1);
my $tar = "$dir/src.tar";

my $w = File::Raw::Archive->create($tar);
$w->add(name => 'a.txt',     content => 'A content', mode => 0644);
$w->add(name => 'sub/');
$w->add(name => 'sub/b.txt', content => 'B content', mode => 0600);
$w->close;

my $dest = "$dir/extracted";
File::Raw::Archive->extract_all($tar, $dest);

ok(-d $dest,           'dest dir created');
ok(-f "$dest/a.txt",   'a.txt extracted');
ok(-d "$dest/sub",     'sub/ extracted');
ok(-f "$dest/sub/b.txt", 'sub/b.txt extracted');

open my $fh, '<', "$dest/a.txt" or die "open: $!";
my $content = do { local $/; <$fh> };
close $fh;
is($content, 'A content', 'a.txt content matches');

# extract_one
my $out = "$dir/just-b.txt";
my $rc = File::Raw::Archive->extract($tar, 'sub/b.txt', $out);
ok($rc, 'extract one returned true');
ok(-f $out, 'extracted single file');
open my $bfh, '<', $out or die "open: $!";
my $bc = do { local $/; <$bfh> };
close $bfh;
is($bc, 'B content', 'extracted single file content matches');

# Not-found: extract returns 0 cleanly without creating dest_path.
my $not_there = "$dir/not-there.txt";
my $nf = File::Raw::Archive->extract($tar, 'no-such-entry.txt', $not_there);
ok(!$nf, 'extract returns false when entry not found');
ok(!-e $not_there, 'no file created when entry not found');

# Path-traversal refusal.
my $bad = "$dir/bad.tar";
my $bw = File::Raw::Archive->create($bad);
$bw->add(name => '../escape.txt', content => 'oops');
$bw->close;
my $bdest = "$dir/bad-dest";
my $err;
eval { File::Raw::Archive->extract_all($bad, $bdest); 1 } or $err = $@;
ok($err, 'extract_all refuses ".." path');
like($err, qr/unsafe path/, 'error mentions unsafe path');

# Windows accepts '\\' as a separator and anchors "C:..." to a drive, so
# an entry spelled either way walks out of the destination there. Refused
# on every platform: the archive is the same archive wherever it lands.
for my $evil ('..\\escape.txt', 'sub\\..\\..\\escape.txt',
              'C:\\escape.txt', 'C:escape.txt', '\\escape.txt') {
    my $t = "$dir/evil.tar";
    my $ew = File::Raw::Archive->create($t);
    $ew->add(name => $evil, content => 'oops');
    $ew->close;
    my $e;
    eval { File::Raw::Archive->extract_all($t, "$dir/evil-dest"); 1 } or $e = $@;
    like($e, qr/unsafe path/, "extract_all refuses '$evil'");
}

done_testing;
