# encoding: Cyrillic
# This file is encoded in Cyrillic.
die "This file is not encoded in Cyrillic.\n" if q{��} ne "\x82\xa0";

use Cyrillic;

print "1..12\n";

# Cyrillic::eval <<'END' has Cyrillic::eval "..."
if (Cyrillic::eval <<'END') {
Cyrillic::eval " if ('��' =~ /[��]/i) { return 1 } else { return 0 } "
END
    print qq{ok - 1 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 1 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval qq{...}
if (Cyrillic::eval <<'END') {
Cyrillic::eval qq{ if ('��' =~ /[��]/i) { return 1 } else { return 0 } }
END
    print qq{ok - 2 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 2 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval '...'
if (Cyrillic::eval <<'END') {
Cyrillic::eval ' if (qq{��} =~ /[��]/i) { return 1 } else { return 0 } '
END
    print qq{ok - 3 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 3 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval q{...}
if (Cyrillic::eval <<'END') {
Cyrillic::eval q{ if ('��' =~ /[��]/i) { return 1 } else { return 0 } }
END
    print qq{ok - 4 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 4 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval $var
my $var = q{ if ('��' =~ /[��]/i) { return 1 } else { return 0 } };
if (Cyrillic::eval <<'END') {
Cyrillic::eval $var
END
    print qq{ok - 5 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 5 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval (omit)
$_ = "if ('��' =~ /[��]/i) { return 1 } else { return 0 }";
if (Cyrillic::eval <<'END') {
Cyrillic::eval
END
    print qq{ok - 6 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 6 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has Cyrillic::eval {...}
if (Cyrillic::eval <<'END') {
Cyrillic::eval { if ('��' =~ /[��]/i) { return 1 } else { return 0 } }
END
    print qq{ok - 7 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 7 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has "..."
if (Cyrillic::eval <<'END') {
if ('��' =~ /[��]/i) { return "1" } else { return "0" }
END
    print qq{ok - 8 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 8 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has qq{...}
if (Cyrillic::eval <<'END') {
if ('��' =~ /[��]/i) { return qq{1} } else { return qq{0} }
END
    print qq{ok - 9 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 9 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has '...'
if (Cyrillic::eval <<'END') {
if ('��' =~ /[��]/i) { return '1' } else { return '0' }
END
    print qq{ok - 10 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 10 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has q{...}
if (Cyrillic::eval <<'END') {
if ('��' =~ /[��]/i) { return q{1} } else { return q{0} }
END
    print qq{ok - 11 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 11 $^X @{[__FILE__]}\n};
}

# Cyrillic::eval <<'END' has $var
my $var1 = 1;
my $var0 = 0;
if (Cyrillic::eval <<'END') {
if ('��' =~ /[��]/i) { return $var1 } else { return $var0 }
END
    print qq{ok - 12 $^X @{[__FILE__]}\n};
}
else {
    print qq{not ok - 12 $^X @{[__FILE__]}\n};
}

__END__
