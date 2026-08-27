#!perl
# The POD parses, and every module has some.
#
# Also the house rules, which are not stylistic: an em dash in POD renders as
# a different character on the terminals half the users read this on, and a
# module without POD is a module nobody can use from the outside.
use 5.010;
use strict;
use warnings;
use Test::More;

eval { require Test::Pod; Test::Pod->VERSION('1.22'); 1 }
    or plan skip_all => 'Test::Pod 1.22 required';

my @pm = Test::Pod::all_pod_files('lib');
my @prose = grep { -f } qw(Changes README);
plan tests => @pm * 4 + @prose;

for my $f (@prose) {
    open my $fh, '<', $f or die "$f: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    unlike($src, qr/\x{2014}|\x{2013}/, "$f: no em or en dashes");
}

for my $f (@pm) {
    Test::Pod::pod_file_ok($f, "$f: POD parses");

    open my $fh, '<', $f or die "$f: $!";
    my $src = do { local $/; <$fh> };
    close $fh;

    # Every module says what it is, and shows how to use it.
    like($src, qr/^=head1 NAME\s+\S+ - \S/m, "  $f: NAME with an abstract");
    like($src, qr/^=head1 (?:SYNOPSIS|DESCRIPTION)$/m,
         "  $f: SYNOPSIS or DESCRIPTION");

    # No em or en dashes, here or in Changes and the documentation tree.
    unlike($src, qr/\x{2014}|\x{2013}/, "  $f: no em or en dashes");
}
