# encoding: EUCTW
# This file is encoded in EUC-TW.
die "This file is not encoded in EUC-TW.\n" if q{あ} ne "\xa4\xa2";

use EUCTW;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいいいいう' =~ /(あい*いう)/) {
    if ("$1" eq "あいいいいう") {
        print "ok - 1 $^X $__FILE__ ('あいいいいう' =~ /あい*いう/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あいいいいう' =~ /あい*いう/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あいいいいう' =~ /あい*いう/).\n";
}

__END__
