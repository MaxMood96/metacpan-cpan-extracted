# encoding: Hebrew
# This file is encoded in Hebrew.
die "This file is not encoded in Hebrew.\n" if q{��} ne "\x82\xa0";

use Hebrew;
print "1..1\n";

my $__FILE__ = __FILE__;

eval q< '-' =~ /��\/ >;
if ($@) {
    print "ok - 1 $^X $__FILE__ die ('-' =~ /��\\/).\n";
}
else {
    print "not ok - 1 $^X $__FILE__ die ('-' =~ /��\\/).\n";
}

__END__
