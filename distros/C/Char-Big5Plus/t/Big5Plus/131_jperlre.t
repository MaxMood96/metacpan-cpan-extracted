# encoding: Big5Plus
# This file is encoded in Big5Plus.
die "This file is not encoded in Big5Plus.\n" if q{あ} ne "\x82\xa0";

use Big5Plus;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいうう' =~ /^(あいう)$/) {
    print "not ok - 1 $^X $__FILE__ not ('あいうう' =~ /^あいう\$/).\n";
}
else {
    print "ok - 1 $^X $__FILE__ not ('あいうう' =~ /^あいう\$/).\n";
}

__END__
