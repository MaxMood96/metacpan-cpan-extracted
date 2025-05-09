# encoding: Big5Plus
# This file is encoded in Big5Plus.
die "This file is not encoded in Big5Plus.\n" if q{あ} ne "\x82\xa0";

use Big5Plus;
print "1..2\n";

my $__FILE__ = __FILE__;

# 控えめな量指定子を含むパターン (例えば C<.??>やC<\d*?>) は、
# 空文字列とマッチすることができますが、C<jsplit()> のパターンとして用いた場合、
# 組み込みの C<split()> から予想される動作と異なることがあります。

if (join('', map {"($_)"} split(/.??/, 'アイウ')) eq '(ア)(イ)(ウ)') {
    print "ok - 1 $^X $__FILE__ (join('', map {qq{(\$_)}} split(/.??/, 'アイウ')) eq '(ア)(イ)(ウ)')\n";
}
else {
    print "not ok - 1 $^X $__FILE__ (join('', map {qq{(\$_)}} split(/.??/, 'アイウ')) eq '(ア)(イ)(ウ)')\n";
}

if (join('', map {"($_)"} split(/\d*?/, 'アイウ')) eq '(ア)(イ)(ウ)') {
    print "ok - 2 $^X $__FILE__ (join('', map {qq{(\$_)}} split(/\\d*?/, 'アイウ')) eq '(ア)(イ)(ウ)')\n";
}
else {
    print "not ok - 2 $^X $__FILE__ (join('', map {qq{(\$_)}} split(/\\d*?/, 'アイウ')) eq '(ア)(イ)(ウ)')\n";
}

__END__

