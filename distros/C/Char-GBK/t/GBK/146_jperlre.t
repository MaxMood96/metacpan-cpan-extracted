# encoding: GBK
# This file is encoded in GBK.
die "This file is not encoded in GBK.\n" if q{あ} ne "\x82\xa0";

use GBK;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('ああう' =~ /(あ[い-え])/) {
    if ("$1" eq "あう") {
        print "ok - 1 $^X $__FILE__ ('ああう' =~ /あ[い-え]/).\n";
    }
    else {
        print "not ok - 1 $^X $__FILE__ ('ああう' =~ /あ[い-え]/).\n";
    }
}
else {
    print "not ok - 1 $^X $__FILE__ ('ああう' =~ /あ[い-え]/).\n";
}

__END__
