# encoding: Hebrew
# This file is encoded in Hebrew.
die "This file is not encoded in Hebrew.\n" if q{��} ne "\x82\xa0";

use Hebrew;

print "1..12\n";

my $var = '';

# Hebrew::eval $var has Hebrew::eval "..."
$var = <<'END';
Hebrew::eval " if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } "
END
if (Hebrew::eval $var) {
    print qq{ok - 1 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 1 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval qq{...}
$var = <<'END';
Hebrew::eval qq{ if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } }
END
if (Hebrew::eval $var) {
    print qq{ok - 2 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 2 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval '...'
$var = <<'END';
Hebrew::eval ' if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } '
END
if (Hebrew::eval $var) {
    print qq{ok - 3 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 3 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval q{...}
$var = <<'END';
Hebrew::eval q{ if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } }
END
if (Hebrew::eval $var) {
    print qq{ok - 4 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 4 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval $var
$var = <<'END';
Hebrew::eval $var2
END
my $var2 = q{ if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } };
if (Hebrew::eval $var) {
    print qq{ok - 5 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 5 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval (omit)
$var = <<'END';
Hebrew::eval
END
$_ = "if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 }";
if (Hebrew::eval $var) {
    print qq{ok - 6 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 6 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has Hebrew::eval {...}
$var = <<'END';
Hebrew::eval { if (Hebrew::length(q{�����������������������������������������������}) == 47) { return 1 } else { return 0 } }
END
if (Hebrew::eval $var) {
    print qq{ok - 7 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 7 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has "..."
$var = <<'END';
if (Hebrew::length(q{�����������������������������������������������}) == 47) { return "1" } else { return "0" }
END
if (Hebrew::eval $var) {
    print qq{ok - 8 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 8 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has qq{...}
$var = <<'END';
if (Hebrew::length(q{�����������������������������������������������}) == 47) { return qq{1} } else { return qq{0} }
END
if (Hebrew::eval $var) {
    print qq{ok - 9 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 9 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has '...'
$var = <<'END';
if (Hebrew::length(q{�����������������������������������������������}) == 47) { return '1' } else { return '0' }
END
if (Hebrew::eval $var) {
    print qq{ok - 10 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 10 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has q{...}
$var = <<'END';
if (Hebrew::length(q{�����������������������������������������������}) == 47) { return q{1} } else { return q{0} }
END
if (Hebrew::eval $var) {
    print qq{ok - 11 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 11 $^X @{[__FILE__]}\n};
}

# Hebrew::eval $var has $var
$var = <<'END';
if (Hebrew::length(q{�����������������������������������������������}) == 47) { return $var1 } else { return $var0 }
END
my $var1 = 1;
my $var0 = 0;
if (Hebrew::eval $var) {
    print qq{ok - 12 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 12 $^X @{[__FILE__]}\n};
}

__END__
