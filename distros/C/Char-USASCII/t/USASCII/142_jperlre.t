# encoding: USASCII
# This file is encoded in US-ASCII.
die "This file is not encoded in US-ASCII.\n" if q{あ} ne "\x82\xa0";

use USASCII;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あいう' =~ /(あ[いう]え)/) {
    print "not ok - 1 $^X $__FILE__ not ('あいう' =~ /あ[いう]え/).\n";
}
else {
    print "ok - 1 $^X $__FILE__ not ('あいう' =~ /あ[いう]え/).\n";
}

__END__
