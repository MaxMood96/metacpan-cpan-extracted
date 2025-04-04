# encoding: Big5Plus
# This file is encoded in Big5Plus.
die "This file is not encoded in Big5Plus.\n" if q{あ} ne "\x82\xa0";

my $__FILE__ = __FILE__;

use Big5Plus;
print "1..2\n";

if ($^O !~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
    print "ok - 1 # SKIP $^X $0\n";
    print "ok - 2 # SKIP $^X $0\n";
    exit;
}

mkdir('directory',0777);
if (rename('directory','directory2')) {
    print "ok - 1 rename $^X $__FILE__\n";
    rename('directory2','directory');
}
else {
    print "not ok - 1 rename: $! $^X $__FILE__\n";
}
rmdir('directory');

mkdir('D機能',0777);
rmdir('D2機能');
if (rename('D機能','D2機能')) {
    print "ok - 2 rename $^X $__FILE__\n";
    rename('D2機能','D機能');
}
else {
    print "not ok - 2 rename: $! $^X $__FILE__\n";
}
rmdir('D機能');

__END__
