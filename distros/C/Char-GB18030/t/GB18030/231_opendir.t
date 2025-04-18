# encoding: GB18030
# This file is encoded in GB18030.
die "This file is not encoded in GB18030.\n" if q{あ} ne "\x82\xa0";

my $__FILE__ = __FILE__;

use GB18030;
print "1..1\n";

if ($^O !~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
    print "ok - 1 # SKIP $^X $0\n";
    exit;
}

mkdir('directory',0777);
mkdir('D機能',0777);
open(FILE,'>D機能/file1.txt') || die "Can't open file: D機能/file1.txt\n";
print FILE "1\n";
close(FILE);
open(FILE,'>D機能/file2.txt') || die "Can't open file: D機能/file2.txt\n";
print FILE "1\n";
close(FILE);
open(FILE,'>D機能/file3.txt') || die "Can't open file: D機能/file3.txt\n";
print FILE "1\n";
close(FILE);

# opendir
if (opendir(DIR,'D機能')) {
    print "ok - 1 opendir $^X $__FILE__\n";
    closedir(DIR);
}
else {
    print "not ok - 1 opendir: $! $^X $__FILE__\n";
}

unlink('D機能/file1.txt');
unlink('D機能/file2.txt');
unlink('D機能/file3.txt');
rmdir('directory');
rmdir('D機能');

__END__
