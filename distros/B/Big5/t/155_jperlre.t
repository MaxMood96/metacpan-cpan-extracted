# encoding: Big5
# This file is encoded in Big5.
die "This file is not encoded in Big5.\n" if q{あ} ne "\x82\xa0";

use Big5;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいえ' =~ /(あ[^いう]え)/) {
    print "not ok - 1 $^X $__FILE__ not ('あいえ' =~ /あ[^いう]え/).\n";
}
else {
    print "ok - 1 $^X $__FILE__ not ('あいえ' =~ /あ[^いう]え/).\n";
}

__END__
