# encoding: Latin2
# This file is encoded in Latin-2.
die "This file is not encoded in Latin-2.\n" if q{��} ne "\x82\xa0";

use Latin2;
print "1..1\n";

my $__FILE__ = __FILE__;

eval q!'AAA' =~ /[]/!;
if ($@) {
    print "ok - 1 $^X $__FILE__ (!'AAA' =~ /[]/!)\n";
}
else {
    print "not ok - 1 $^X $__FILE__ (!'AAA' =~ /[]/!)\n";
}

__END__
