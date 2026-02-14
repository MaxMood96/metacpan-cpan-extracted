#!/usr/bin/env perl

# Author test: ensure no non-ASCII bytes appear inside POD sections.
# Run with: prove -l xt/
# Skipped under AUTOMATED_TESTING (CPAN testers, CI).

use strict;
use warnings;
use Test2::V0;
use File::Find;

skip_all 'Skipping POD ASCII check under AUTOMATED_TESTING'
    if $ENV{AUTOMATED_TESTING};

my @pm_files;
find(
    sub { push @pm_files, $File::Find::name if /\.pm\z/ },
    'lib',
);

ok(@pm_files, 'found .pm files to scan');

for my $file (sort @pm_files) {
    open my $fh, '<:raw', $file or do {
        fail("cannot open $file: $!");
        next;
    };

    my $in_pod  = 0;
    my $lineno  = 0;
    my @failures;

    while (my $line = <$fh>) {
        $lineno++;
        if ($line =~ /^=\w/) {
            $in_pod = 1;
        }
        elsif ($line =~ /^=cut/) {
            $in_pod = 0;
            next;
        }
        next unless $in_pod;
        if ($line =~ /[\x80-\xff]/) {
            chomp $line;
            push @failures, "  line $lineno: $line";
        }
    }
    close $fh;

    ok(!@failures, "no non-ASCII in POD: $file")
        or diag(join "\n", @failures);
}

done_testing;
