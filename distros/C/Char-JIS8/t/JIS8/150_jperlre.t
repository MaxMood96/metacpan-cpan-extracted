# encoding: JIS8
# This file is encoded in JIS8.
die "This file is not encoded in JIS8.\n" if q{あ} ne "\x82\xa0";

use JIS8;
print "1..1\n";

my $__FILE__ = __FILE__;

eval q< '-' =~ /(あ[]い)/ >;
if ($@) {
    print "ok - 1 $^X $__FILE__ die ('-' =~ /あ[]い/).\n";
}
else {
    print "not ok - 1 $^X $__FILE__ die ('-' =~ /あ[]い/).\n";
}

__END__
