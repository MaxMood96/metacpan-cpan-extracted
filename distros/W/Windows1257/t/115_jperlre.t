# encoding: Windows1257
# This file is encoded in Windows-1257.
die "This file is not encoded in Windows-1257.\n" if q{あ} ne "\x82\xa0";

use Windows1257;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいいう' =~ /(あい+いう)/) {
    if ("$1" eq "あいいう") {
        print "ok - 1 $^X $__FILE__ ('あいいう' =~ /あい+いう/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あいいう' =~ /あい+いう/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あいいう' =~ /あい+いう/).\n";
}

__END__
