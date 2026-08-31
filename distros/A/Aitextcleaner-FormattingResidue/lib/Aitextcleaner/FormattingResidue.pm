package Aitextcleaner::FormattingResidue;

use strict;
use warnings;
use Exporter qw(import);

our $VERSION = '0.2.0';
our @EXPORT_OK = qw(clean_formatting_residue);

sub clean_formatting_residue {
    my ($text) = @_;
    die 'text must be a string' if !defined($text) || ref($text);
    $text =~ s{</?(?:address|article|blockquote|br|div|li|p|pre|section)\b[^>]*>}{\n}gi;
    $text =~ s{<[^>]*>}{}g;
    $text =~ s/&amp;/\&/g;
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&quot;/"/g;
    $text =~ s/&#39;|&apos;/'/g;
    $text =~ s/&nbsp;/ /g;
    $text =~ s/“/"/g;
    $text =~ s/”/"/g;
    $text =~ s/‘/'/g;
    $text =~ s/’/'/g;
    $text =~ s/–/-/g;
    $text =~ s/—/-/g;
    $text =~ s/…/.../g;
    $text =~ s/[ \t]+\n/\n/g;
    $text =~ s/\n{3,}/\n\n/g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

1;
