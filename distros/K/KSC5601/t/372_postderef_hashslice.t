# encoding: KSC5601
# This file is encoded in KS C 5601.
die "This file is not encoded in KS C 5601.\n" if q{あ} ne "\xa4\xa2";

use KSC5601;

BEGIN {
    print "1..2\n";
    if ($] >= 5.020) {
        require feature;
        feature::->import('postderef');
        require warnings;
        warnings::->unimport('experimental::postderef');
    }
    else{
        for my $tno (1..2) {
            print qq{ok - $tno SKIP $^X @{[__FILE__]}\n};
        }
        exit;
    }
}

# same as %$aref[...]
@array = (qw(あか あお き むらさきいろ));
$aref = \@array;
if (join(',',$aref->%[0,1]) eq join(',',%$aref[0,1])) {
    print qq{ok - 1 join(',',\$aref->%[0,1]) eq join(',',%\$aref[0,1]) $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 1 join(',',\$aref->%[0,1]) eq join(',',%\$aref[0,1]) $^X @{[__FILE__]}\n};
}

# same as %$href{...}
%hash = (red => 1, blue => 2, yellow => 3, violet => 4);
$href = \%hash;
if (join(',',$href->%{qw(blue yellow)}) eq join(',',%$href{qw(blue yellow)})) {
    print qq{ok - 2 join(',',\$href->%{qw(blue yellow)}) eq join(',',%\$href{qw(blue yellow)}) $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 2 join(',',\$href->%{qw(blue yellow)}) eq join(',',%\$href{qw(blue yellow)}) $^X @{[__FILE__]}\n};
}

__END__
