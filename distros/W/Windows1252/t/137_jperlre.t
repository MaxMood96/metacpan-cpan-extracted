# encoding: Windows1252
# This file is encoded in Windows-1252.
die "This file is not encoded in Windows-1252.\n" if q{あ} ne "\x82\xa0";

use Windows1252;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいう' =~ /()$/) {
    if ("$1" eq "") {
        print "ok - 1 $^X $__FILE__ ('あいう' =~ /\$/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あいう' =~ /\$/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あいう' =~ /\$/).\n";
}

__END__
