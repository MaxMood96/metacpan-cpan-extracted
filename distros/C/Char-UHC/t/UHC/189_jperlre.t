# encoding: UHC
# This file is encoded in UHC.
die "This file is not encoded in UHC.\n" if q{あ} ne "\x82\xa0";

use UHC;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あ-い' =~ /あ[^-]い/) {
    print "not ok - 1 $^X $__FILE__ ('あ-い' =~ /あ[^-]い/)\n";
}
else {
    print "ok - 1 $^X $__FILE__ ('あ-い' =~ /あ[^-]い/)\n";
}

__END__
