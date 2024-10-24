use warnings;
use strict;
use Test::More;

use Data::Dumper;
use STEVEB::Dist::Mgr qw(:all);

use lib 't/lib';
use Helper qw(:all);

my $work = 't/data/work/.gitignore';
my $orig = 't/data/orig/.gitignore';

my $dir = 't/data/work';

unlink_git_ignore();

my @c = git_ignore($dir);

open my $o_fh, '<', $orig or die $!;
open my $w_fh, '<', $work or die $!;

my @o = <$o_fh>;
my @w = <$w_fh>;

close $o_fh;
close $w_fh;

for (0..$#w) {
    chomp $w[$_];
    chomp $o[$_];
    chomp $c[$_];

    is $w[$_], $c[$_], "new .gitignore line $_ matches return content";
    is $w[$_], $o[$_], "new .gitignore line $_ matches original file";
}

unlink_git_ignore();

done_testing;

