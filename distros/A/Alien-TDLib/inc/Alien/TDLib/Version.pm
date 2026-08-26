package Alien::TDLib::Version;

use strict;
use warnings;

# Floor for a system libtdjson, and deliberately no ceiling: capping it would
# start rejecting installs the day TDLib ships a new minor.
our $MIN_VERSION = '1.8.66';

sub parse {
    my ($v) = @_;
    return unless defined $v && $v =~ /^\s*(\d+(?:\.\d+)*)/;
    return split /\./, $1;
}

sub compare {
    my ($a, $b) = @_;
    my @a = parse($a);
    my @b = parse($b);
    return unless @a && @b;
    while (@a || @b) {
        my ($x, $y) = (shift(@a) // 0, shift(@b) // 0);
        return $x <=> $y if $x != $y;
    }
    return 0;
}

sub range { "$MIN_VERSION or newer" }

# -> ($ok, $why); $why is a log-ready sentence in both outcomes
sub check {
    my ($version) = @_;
    return (0, 'its version could not be determined')
        unless defined compare($version, $MIN_VERSION);
    return (0, "version $version is older than the supported minimum $MIN_VERSION")
        if compare($version, $MIN_VERSION) < 0;
    return (1, "version $version is $MIN_VERSION or newer");
}

1;
