# encoding: Windows1257
# This file is encoded in Windows-1257.
die "This file is not encoded in Windows-1257.\n" if q{あ} ne "\x82\xa0";

use Windows1257;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいう' =~ /(あい{0,1}う)/) {
    if ("$1" eq "あいう") {
        print "ok - 1 $^X $__FILE__ ('あいう' =~ /あい{0,1}う/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あいう' =~ /あい{0,1}う/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あいう' =~ /あい{0,1}う/).\n";
}

__END__
