package EBook::Ishmael::EBook::CB7;
use 5.016;
our $VERSION = '1.08';
use strict;
use warnings;

use parent 'EBook::Ishmael::EBook::CB';

use File::Which;

use EBook::Ishmael::ShellQuote qw(shell_quote);

my $MAGIC = pack "C*", 0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c;

my $SZIP = which('7z') // which('7za');

our $CAN_TEST = defined $SZIP;

sub heuristic {

    my $class = shift;
    my $file  = shift;
    my $fh    = shift;

    return 0 unless $file =~ /\.cb7$/;

    read $fh, my $mag, length $MAGIC;

    return $mag eq $MAGIC;

}

sub _un7zip {

    my $zip = shift;
    my $out = shift;

    unless (defined $SZIP) {
        die "Cannot un-7zip $zip; 7z not installed\n";
    }

    my $qout = shell_quote("-o$out");
    my $qzip = shell_quote($zip);
    qx/$SZIP x $qout $qzip/;

    unless ($? >> 8 == 0) {
        die "Failed to run '$SZIP' on $zip\n";
    }

    return 1;

}

sub extract {

    my $self = shift;
    my $out  = shift;

    _un7zip($self->{Source}, $out);

    return 1;

}

sub format { 'CB7' }

1;
