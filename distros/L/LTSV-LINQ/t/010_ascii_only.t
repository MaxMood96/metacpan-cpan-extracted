######################################################################
#
# t/010_ascii_only.t - Verify LTSV::LINQ.pm is US-ASCII only
#
######################################################################

BEGIN {
    unshift @INC, 'lib';
    $| = 1;
    print "1..2\n";
}

my $testno = 1;

sub ok {
    my($test, $name) = @_;
    printf "%s %d - %s\n", ($test ? 'ok' : 'not ok'), $testno++, $name || '';
    return $test;
}

#---------------------------------------------------------------------
# Check LTSV::LINQ.pm for non-ASCII characters
#---------------------------------------------------------------------

# Test 1: Check main module
open(FH, "< lib/LTSV/LINQ.pm") or die "Cannot open lib/LTSV/LINQ.pm: $!";
my $non_ascii_count = 0;
my $line_number = 0;
while (my $line = <FH>) {
    $line_number++;
    if ($line =~ /[^\x00-\x7F]/) {
        $non_ascii_count++;
        print "# Line $line_number contains non-ASCII: $line" if $non_ascii_count <= 5;
    }
}
close(FH);
ok($non_ascii_count == 0, 'LTSV::LINQ.pm contains only US-ASCII characters');

# Test 2: Report statistics
my $passed = ($non_ascii_count == 0);
if ($passed) {
    ok(1, 'All characters in valid US-ASCII range (0x00-0x7F)');
}
else {
    ok(0, "Found $non_ascii_count lines with non-ASCII characters");
}

