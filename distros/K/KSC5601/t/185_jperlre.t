# encoding: KSC5601
# This file is encoded in KS C 5601.
die "This file is not encoded in KS C 5601.\n" if q{あ} ne "\xa4\xa2";

use KSC5601;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あ]い' =~ /あ[]]い/) {
    print "ok - 1 $^X $__FILE__ ('あ]い' =~ /あ[]]い/)\n";
}
else {
    print "not ok - 1 $^X $__FILE__ ('あ]い' =~ /あ[]]い/)\n";
}

__END__
