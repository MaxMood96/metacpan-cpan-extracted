# encoding: Latin7
# This file is encoded in Latin-7.
die "This file is not encoded in Latin-7.\n" if q{あ} ne "\x82\xa0";

use Latin7;
print "1..1\n";

my $__FILE__ = __FILE__;

if ('あ-い' =~ /(あ\sい)/) {
    print "not ok - 1 $^X $__FILE__ not ('あ-い' =~ /あ\\sい/).\n";
}
else {
    print "ok - 1 $^X $__FILE__ not ('あ-い' =~ /あ\\sい/).\n";
}

__END__
