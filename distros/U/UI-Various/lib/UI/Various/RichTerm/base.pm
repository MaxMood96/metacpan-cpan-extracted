package UI::Various::RichTerm::base;

# Author, Copyright and License: see end of file

=head1 NAME

UI::Various::RichTerm::base - abstract helper class for RichTerm's UI elements

=head1 SYNOPSIS

    # This module should only be used by the UI::Various::RichTerm UI
    # element classes!

=head1 ABSTRACT

This module provides some helper functions for the UI elements of the rich
console.

=head1 DESCRIPTION

The documentation of this module is only intended for developers of the
package itself.

All functions of the module will be included as second "base
class" (in C<@ISA>).  Note that this is not a diamond pattern as this "base
class" does not import anything besides C<Exporter>.

=head2 Global Definitions

=over

=cut

#########################################################################

use v5.14;
use strictures;
no indirect 'fatal';
no multidimensional;
use warnings 'once';

use Text::Wrap;
$Text::Wrap::huge = 'overflow';
$Text::Wrap::unexpand = 0;

our $VERSION = '1.00';

use UI::Various::core;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(%D);

#########################################################################

=item B<%D>

a hash of decoration characters for window borders (C<W1> to C<W9> without
C<W5>), box borders (C<B*>, C<b*> and C<c5>), check boxes (C<CL> and C<CR>),
radio buttons (C<RL> and C<RR>), normal buttons (C<BL> and C<BR>), selected
(C<SL1> and C<SL0>) and underline (C<UL1> and C<UL0>).

=cut

use constant DECO_ASCII => (W7 => '#', W8 => '=', W9 => '#',
			    W4 => '"',		  W6 => '"',
			    W1 => '#', W2 => '=', W3 => '#',
			    B7 => '+', B8 => '-', B9 => '+',
				       b8 => '+',
			    B4 => '|', B5 => '|', B6 => '|',
			    b4 => '+', b5 => '+', b6 => '+',
				       c5 => '-',
			    B1 => '+', B2 => '-', B3 => '+',
				       b2 => '+',
			    BL => '[', BR => ']',
			    CL => '[', CR => ']',
			    RL => '(', RR => ')',
			    SL1 => "\e[7m", SL0 => "\e[27m",
			    UL1 => "\e[4m", UL0 => "\e[24m");

# https://www.utf8-chartable.de/unicode-utf8-table.pl?start=9472&number=128
# (not yet supported, we'll probably check I18N::Langinfo::langinfo):
use constant DECO_UTF8 => (W7 => "\x{2554}", W8 => "\x{2550}", W9 => "\x{2557}",
			   W4 => "\x{2551}",		       W6 => "\x{2551}",
			   W1 => "\x{255a}", W2 => "\x{2550}", W3 => "\x{255d}",
			   B7 => "\x{250c}", B8 => "\x{2500}", B9 => "\x{2510}",
					     b8 => "\x{252C}",
			   B4 => "\x{2502}", B5 => "\x{2502}", B6 => "\x{2502}",
			   b4 => "\x{251C}", b5 => "\x{253C}", b6 => "\x{2524}",
					     c5 => "\x{2500}",
			   B1 => "\x{2514}", B2 => "\x{2500}", B3 => "\x{2518}",
					     b2 => "\x{2534}",
			   BL => "\x{2503}", BR => "\x{2503}",
			   CL => '[', CR => ']',
			   RL => '(', RR => ')',
			   SL1 => "\e[7m", SL0 => "\e[27m",
			   UL1 => "\e[4m", UL0 => "\e[24m");

our %D =
    defined $ENV{LANG} && $ENV{LANG} =~ m/\.UTF-?8/i ? DECO_UTF8 : DECO_ASCII;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#########################################################################
#########################################################################

=back

=head1 METHODS

The module provides the following common (internal) methods for all
UI::Various::RichTerm UI element classes:

=cut

#########################################################################

=head2 B<_size> - determine size of UI element

    ($width, $height) = $ui_element->_size($string, $content_width);

=head3 example:

    my ($w, $h) = $self->_size($self->text, $content_width);

=head3 parameters:

    $string             the string to be analysed
    $content_width      preferred width of content

=head3 description:

This method determines the width and height of a UI element.

If the UI element has it's own defined (not inherited) widht and/or height,
no other calculation is made (no matter if the string will fit or not).

If no own width is defined, the text will be wrapped into lines no longer
than the given preferred maximum width and the length of the longest of line
is returned.  If a sub-string has no word boundary to break it into chunks
smaller than C<$content_width>, C<$content_width> is returned even though
the string will not really fit when it will be displayed later.)

If no own height is defined, the number of lines of the wrapped string is
returned.

=head3 returns:

width and height of the string when it will be displayed later

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _size($$$)
{
    my ($self, $string, $content_width) = @_;

    my ($w, $h) = ($self->{width}, $self->{height});
    $w  and  $h  and  return ($w, $h);

    $Text::Wrap::columns = ($w ? $w : $content_width) + 1;
    $string = wrap('', '', $string);
    my @lines = split "\n", $string;

    unless ($w)
    {
	$w = 0;
	local $_;
	foreach (map { length($_) } @lines)
	{   $w >= $_  or  $w = $_;   }
	$w <= $content_width  or  $w = $content_width;
    }

    $h  or  $h = @lines;
    return ($w, $h);
}

#########################################################################

=head2 B<_color_on_off> - compute escape sequences needed for colours

    ($colour_on, $colour_off) = $ui_element->_color_on_off();

=head3 example:

    my ($col_on, $col_off) = $ui_element->_color_on_off();

=head3 description:

This method determines the escape sequences needed to set background and
foreground colours, and to switch them off again.

=head3 returns:

escape sequence to set the colours and escape sequence to turn them of

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _color_on_off($)
{
    my ($self) = @_;
    my ($col_on, $col_off) = ('', '');
    if (defined $self->{bg}  or  defined $self->{fg})
    {
	defined $self->{bg}  and
	    $col_on .= "\e[48;5;" .
	    (16 + UI::Various::core::_tui_color($self->{bg})) . 'm';
	defined $self->{fg}  and
	    $col_on .= "\e[38;5;" .
	    (16 + UI::Various::core::_tui_color($self->{fg})) . 'm';
	$col_off = "\e[39;49m";		# reset colours to default
    }
    return ($col_on, $col_off);
}

#########################################################################

=head2 B<_color_simplify> - remove unnecessary escape sequences

    $simplified = $ui_element->_color_simplify($coloured_text);

=head3 example:

    $text = $ui_element->_color_simplify($text);

=head3 description:

This method removes unnecessary escape sequences from a text.  It might cost
a bit of performance, but eases debugging of wrong colours.

=head3 returns:

simplified text

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _color_simplify($$)
{
    my ($self, $text) = @_;
    if (defined $self->{bg}  or  defined $self->{fg})
    {
	$text =~ s{(?:\e\[[34]8;5;\d{1,3}m)+(?=\e\[39;49m)}{}g;
	$text =~ s{(?:\e\[38;5;\d{1,3}m)+(?=\e\[38;5;\d{1,3}m)}{}g;
	$text =~ s{(?:\e\[48;5;\d{1,3}m)+(?=\e\[48;5;\d{1,3}m)}{}g;
	$text =~ s{(?:\e\[48;5;\d{1,3}m\e\[38;5;\d{1,3}m)+(?=\e\[48;5;\d{1,3}m\e\[38;5;\d{1,3}m)}{}g;
	$text =~ s{(?:\e\[39;49m)+(?=\e\[39;49m)}{}g;
	$text =~ s{(\e\[39;49m +)(?:\e\[39;49m)+}{$1}g;
    }
    return $text;
}

#########################################################################

=head2 B<_format> - format text according to given options

    $string = $ui_element->_format($prefix, $decoration_before, $effect_before,
                                   $text, $effect_after, $decoration_after,
                                   $width, $height [, $no_wrap]);
        or

    $string = $ui_element->_format($prefix, $decoration_before, $effect_before,
                                   \@text, $effect_after, $decoration_after,
                                   $width, $height);

=head3 example:

    my ($w, $h) = $self->_size($self->text, $content_width);
    $string = $self->_format('(1) ', '', '[ ', $self->text, ' ]', '', $w, $h);

=head3 parameters:

    $prefix             text in front of first line
    $decoration_before  decoration before content of each line
    $effect_before      effect before content of each line
    $text               string to be wrapped or reference to wrapped text lines
    $effect_after       end of effect after content of each line
    $decoration_after   decoration after content of each line
    $width              the width returned by _size above
    $height             the height returned by _size above
    $no_wrap            optional flag to inhibit wrapping of a text string

=head3 description:

This method formats the given text into a text box of the previously
(C<L<_size|/_size - determine size of UI element>>) determined width and
height, decorates it with some additional strings (e.g. to symbolise a
button) and a prefix set by its parent.  Note that the (latter) prefix is
only added to the first line with text, all additional lines gets a blank
prefix of the same length.

Also note that the given text can either be a string which is wrapped or a
reference to an array of already wrapped strings that only need the final
formatting.

The decorations and prefix will cause the resulting text box to be wider
than the given width, which only describes the width of the text itself.
The effect is sort of a zero-width decoration (applied to the text without
padding), usually an ANSI escape sequence.

And as already described under C<L<_size|/_size - determine size of UI
element>> above, the layout will be broken if it can't fit.  The display of
everything is preferred over cutting of possible important parts.

=head3 returns:

the rectangular text box for the given string

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _format($$$$$$$$$;$)
{
    my ($self, $prefix, $deco_before, $effect_before, $text,
	$effect_after, $deco_after, $w, $h, $no_wrap) = @_;
    my $alignment = 7;
    defined $self->{align}  and  $alignment = $self->{align};

    my $len_p = length($prefix);
    my ($len_d_bef, $len_d_aft) = (length($deco_before), length($deco_after));
    my $blank_prefix = ' ' x $len_p;
    local $_;

    my ($col_on, $col_off) = $self->_color_on_off;

    # format text-box:
    # wrap text, if applicable:
    my @text;
    if (ref($text) eq 'ARRAY')
    {   push @text, split("\n", $_) foreach @{$text};   }
    elsif ($no_wrap)
    {   @text = split "\n", $text;   }
    else
    {
	$Text::Wrap::columns = $w + 1;
	@text = split "\n", wrap('', '', $text);
    }
    foreach (0..$#text)
    {
	my $text_no_ansi = $text[$_];
	$text_no_ansi =~ s/\e[[0-9;]*m//g;
	my $l = length($text_no_ansi);
	$text[$_] = $effect_before . $text[$_] . $effect_after;
	if ($l < $w)
	{
	    my ($pad1, $pad2) = ('', '');
	    # default alignments 1/4/7:
	    if (not defined $self->{align}  or  $self->{align} % 3 == 1)
	    {   $pad2 = ' ' x ($w - $l);    }
	    # alignments 3/6/9:
	    elsif ($self->{align} % 3 == 0)
	    {   $pad1 = ' ' x ($w - $l);    }
	    # alignments 2/5/8:
	    else
	    {
		my $l2 = int(($w - $l) / 2);
		my $l1 = $w - $l - $l2;
		$pad1 = ' ' x $l1;
		$pad2 = ' ' x $l2;
	    }
	    $text[$_] = $pad1 . $text[$_] . $col_on . $pad2 . $col_off;
	}
	$text[$_] = ($_ == 0 ? $prefix : $blank_prefix) .
	    $col_on . $deco_before . $text[$_] .
	    $col_on . $deco_after . $col_off;
    }
    if ($h > @text)
    {
	my $empty =
	    $blank_prefix .
	    $col_off . (' ' x ($len_d_bef + $w + $len_d_aft)) . $col_off;
	my $l = $h - @text;
	# default alignments 7-9:
	if (not defined $self->{align}  or  $self->{align} >= 7)
	{   push @text, ($empty) x $l;   }
	# alignments 1-3:
	elsif ($self->{align} <= 3)
	{   unshift @text, ($empty) x $l;   }
	# alignments 4-6:
	else
	{
	    my $l2 = int($l / 2);
	    my $l1 = $l - $l2;
	    unshift @text, ($empty) x $l1;
	    push @text, ($empty) x $l2;
	}
    }

    return join("\n", @text);
}

1;

#########################################################################
#########################################################################

=head1 SEE ALSO

L<UI::Various>

=head1 LICENSE

Copyright (C) Thomas Dorner.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  See LICENSE file for more details.

=head1 AUTHOR

Thomas Dorner E<lt>dorner (at) cpan (dot) orgE<gt>

=cut
