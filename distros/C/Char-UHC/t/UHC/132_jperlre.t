# encoding: UHC
# This file is encoded in UHC.
die "This file is not encoded in UHC.\n" if q{あ} ne "\x82\xa0";

use UHC;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいうう' =~ /^(あいう)/) {
    if ("$1" eq "あいう") {
        print "ok - 1 $^X $__FILE__ ('あいうう' =~ /^あいう/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あいうう' =~ /^あいう/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あいうう' =~ /^あいう/).\n";
}

__END__
