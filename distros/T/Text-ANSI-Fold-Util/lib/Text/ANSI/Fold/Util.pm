package Text::ANSI::Fold::Util;
our $VERSION = "1.05";

use v5.14;
use utf8;
use warnings;
use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK;
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use List::Util qw(max);
use Text::ANSI::Fold qw(ansi_fold);

=encoding utf-8

=head1 NAME

Text::ANSI::Fold::Util - Text::ANSI::Fold utilities (width, substr)

=head1 SYNOPSIS

    use Text::ANSI::Fold::Util qw(:all);
    use Text::ANSI::Fold::Util qw(ansi_width ansi_substr);
    ansi_width($text);
    ansi_substr($text, $offset, $width [, $replacement]);

    use Text::ANSI::Fold::Util;
    Text::ANSI::Fold::Util::width($text);
    Text::ANSI::Fold::Util::substr($text, ...);

=head1 VERSION

Version 1.05

=head1 DESCRIPTION

This is a collection of utilities using Text::ANSI::Fold module.  All
functions are aware of ANSI terminal sequence.

=head1 FUNCTION

There are exportable functions start with B<ansi_> prefix, and
unexportable functions without them.

Unless otherwise noted, these functions are executed in the same
context as C<ansi_fold> exported by C<Text::ANSI::Fold> module. That
is, the parameters set by C<< Text::ANSI::Fold->configure >> are
effective.

=over 7

=cut


=item B<width>(I<text>)

=item B<ansi_width>(I<text>)

Returns visual width of given text.

=cut

BEGIN { push @EXPORT_OK, qw(&ansi_width) }
sub ansi_width { goto &width }

sub width {
    (ansi_fold($_[0], -1))[2];
}


=item B<substr>(I<text>, I<offset>, I<width> [, I<replacement>])

=item B<ansi_substr>(I<text>, I<offset>, I<width> [, I<replacement>])

Returns substring just like Perl's B<substr> function, but string
position is calculated by the visible width on the screen instead of
number of characters.  If there is no corresponding substring, undef
is returned always.

If the C<padding> option is specified, then if there is a
corresponding substring, it is padded to the specified width and
returned.

It does not cut the text in the middle of multi-byte character.  If
you want to split the text in the middle of a wide character, specify
the C<splitwide> option.

    Text::ANSI::Fold->configure(splitwide => 1);

If an optional I<replacement> parameter is given, replace the
substring by the replacement and return the entire string.  If 0 is
specified for the width, there may be no error even if the
corresponding substring does not exist.

=cut

BEGIN { push @EXPORT_OK, qw(&ansi_substr) }
sub ansi_substr { goto &substr }

sub substr {
    my($text, $offset, $length, $replacement) = @_;
    if ($offset < 0) {
	$offset = max(0, $offset + ansi_width($text));
    }
    my @s = (state $fold = Text::ANSI::Fold->configure)
	->text($text)
	->chops(width => [ $offset, $length // -1, -1 ]);
    if (defined $replacement) {
	if (defined $s[1]) {
	    $s[0] . $replacement . ($s[2] // '');
	} else {
	    undef;
	}
    } else {
	$s[1];
    }
}


=back

=cut

1;

__END__

=head1 SEE ALSO

L<Text::ANSI::Fold::Util>,
L<https://github.com/tecolicom/Text-ANSI-Fold-Util>

L<Text::ANSI::Tabs>,
L<https://github.com/tecolicom/Text-ANSI-Tabs>

L<Text::ANSI::Fold>,
L<https://github.com/tecolicom/Text-ANSI-Fold>

L<Text::Tabs>

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2020-2024 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#  LocalWords:  ansi utf substr exportable unexportable
#  LocalWords:  tabstop tabhead tabspace Kazumasa Utashiro
