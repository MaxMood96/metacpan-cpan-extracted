# encoding: Greek
# This file is encoded in Greek.
die "This file is not encoded in Greek.\n" if q{あ} ne "\x82\xa0";

use Greek;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あ-' =~ /(あ[-い])/) {
    if ("$1" eq "あ-") {
        print "ok - 1 $^X $__FILE__ ('あ-' =~ /あ[-い]/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('あ-' =~ /あ[-い]/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('あ-' =~ /あ[-い]/).\n";
}

__END__
