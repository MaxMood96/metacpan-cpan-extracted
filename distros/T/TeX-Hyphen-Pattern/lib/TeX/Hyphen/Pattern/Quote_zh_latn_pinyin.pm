## no critic qw(RequirePodSections)    # -*- cperl -*-
# This file is auto-generated by the Perl TeX::Hyphen::Pattern Suite hyphen
# pattern catalog generator. This code generator comes with the
# TeX::Hyphen::Pattern module distribution in the tools/ directory
#
# Do not edit this file directly.

package TeX::Hyphen::Pattern::Quote_zh_latn_pinyin v1.1.8;
use strict;
use warnings;
use 5.014000;
use utf8;

use Moose;

my $pattern_file = q{};
while (<DATA>) {
    $pattern_file .= $_;
}

sub pattern_data {
    return $pattern_file;
}

sub version {
    return $TeX::Hyphen::Pattern::Quote_zh_latn_pinyin::VERSION;
}

1;
## no critic qw(RequirePodAtEnd RequireASCII ProhibitFlagComments)

=encoding utf8

=head1 C<Quote_zh_latn_pinyin> hyphenation pattern class

=head1 SUBROUTINES/METHODS

=over 4

=item $pattern-E<gt>pattern_data();

Returns the pattern data.

=item $pattern-E<gt>version();

Returns the version of the pattern package.

=back

=head1 Copyright

The copyright of the patterns is not covered by the copyright of this package
since this pattern is generated from the source at
L<svn://tug.org/texhyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/quote/hyph-quote-zh-latn-pinyin.tex>

The copyright of the source can be found in the DATA section in the source of
this package file.

=cut

__DATA__
\bgroup
\lccode`\’=`\’
\patterns{
’1a
’1e
’1o
}
\egroup

