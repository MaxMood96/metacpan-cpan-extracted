# encoding: JIS8
# This file is encoded in JIS8.
die "This file is not encoded in JIS8.\n" if q{��} ne "\x82\xa0";

print "1..1\n";

my $__FILE__ = __FILE__;

if ($] < 5.014) {
    print "ok - 1 # SKIP $^X $__FILE__\n";
    exit;
}

if (open(TEST,">@{[__FILE__]}.t")) {
    print TEST <DATA>;
    close(TEST);
    system(qq{$^X @{[__FILE__]}.t});
    unlink("@{[__FILE__]}.t");
    unlink("@{[__FILE__]}.t.e");
}

__END__
# encoding: JIS8
use JIS8;

my $__FILE__ = __FILE__;

$var = '0123456789';
JIS8::substr($var,2,6) =~ tr/2367/abcd/;
if ($var eq '01ab45cd89') {
    print "ok - 1 $^X $__FILE__\n";
}
else {
    print "not ok - 1 $^X $__FILE__\n";
}

__END__
