package CleanPaste::Normalizer;

use strict;
use warnings;
use Exporter qw(import);
use Unicode::Normalize qw(NFKC);

our $VERSION = '0.2.0';
our @EXPORT_OK = qw(normalize_pasted_text);

my $ZERO_WIDTH = qr/[\x{200B}\x{200C}\x{200D}\x{200E}\x{200F}\x{202A}\x{202B}\x{202C}\x{202D}\x{202E}\x{2060}\x{FEFF}]/;
my $UNICODE_SPACES = qr/[\x{00A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/;

sub normalize_pasted_text {
    my ($text) = @_;
    die "text must be a string" unless defined $text;
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;
    $text = NFKC($text);
    $text =~ s/$ZERO_WIDTH//g;
    $text =~ s/$UNICODE_SPACES/ /g;
    $text =~ s/[ \t]+\n/\n/g;
    $text =~ s/[ \t]+$//;
    return $text;
}

1;
