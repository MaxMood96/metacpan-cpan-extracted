# encoding: TIS620
# This file is encoded in TIS-620.
die "This file is not encoded in TIS-620.\n" if q{あ} ne "\x82\xa0";

use TIS620;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('ああいうえ' =~ /(あいう)$/) {
    print "not ok - 1 $^X $__FILE__ not ('ああいうえ' =~ /あいう\$/).\n";
}
else {
    print "ok - 1 $^X $__FILE__ not ('ああいうえ' =~ /あいう\$/).\n";
}

__END__
