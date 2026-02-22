#! perl

use strict;
use warnings;
use Test::More;

use File::StatX qw/statx fstatx STATX_BASIC_STATS/;
use File::Temp 'tempfile';

my ($fh, $filename) = tempfile(TMPDIR => 1);

print $fh "Hello, World!\n";

my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($filename);

for my $stat (statx($filename, 0, STATX_BASIC_STATS), fstatx($fh, 0, STATX_BASIC_STATS)) {
	is($stat->ino, $ino);
	is($stat->mode, $mode);
	is($stat->nlink, $nlink);
	is($stat->uid, $uid);
	is($stat->gid, $gid);
	is($stat->size, $size);
	cmp_ok($stat->atime, '>', $atime);
	cmp_ok($stat->atime, '<', $atime + 1.1);
	cmp_ok($stat->mtime, '>', $mtime);
	cmp_ok($stat->mtime, '<', $mtime + 1.1);
	cmp_ok($stat->ctime, '>', $ctime);
	cmp_ok($stat->ctime, '<', $ctime + 1.1);
	is($stat->blksize, $blksize);
	is($stat->blocks, $blocks);
}

done_testing;
