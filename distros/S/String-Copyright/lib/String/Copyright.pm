use v5.40;
use utf8;
use re (qw/eval/);

use builtin qw(load_module);
no warnings 'experimental::builtin';

my $CAN_RE2 = false;

BEGIN {
	try {
		load_module('re::engine::RE2');
		$CAN_RE2 = true;
	}
	catch ($e) {

		# module not compiled in / not installed
	}
}

package String::Copyright;

=encoding UTF-8

=head1 NAME

String::Copyright - Representation of text-based copyright statements

=head1 VERSION

Version v0.4.1

=cut

our $VERSION = "v0.4.1";

use parent 'Exporter::Tiny';
use Carp     ();
use Log::Any qw($log);

our @EXPORT = qw/copyright/;

use constant {
	PLAINTEXT => 0,
	BLOCKS    => 1,
	FORMAT    => 2,
};

use overload (
	q{""}    => '_compose',
	fallback => 1,
);

=head1 SYNOPSIS

    use String::Copyright;

    my $copyright = copyright(<<'END');
    copr. © 1999,2000 Foo Barbaz <fb@acme.corp> and Acme Corp.
    Copyright (c) 2001,2004 Foo (work address) <foo@zorg.corp>
    Copyright 2003, Foo B. and friends
    © 2000, 2002 Foo Barbaz <foo@bar.baz>
    END

    print $copyright;

    # Copyright 1999-2000 Foo Barbaz <fb@acme.com> and Acme Corp.
    # Copyright 2000, 2002 Foo Barbaz and Acme Corp.
    # Copyright 2001, 2004 Foo (work address) <foo@zorg.org>
    # Copyright 2003 Foo B. and friends

=head1 DESCRIPTION

L<String::Copyright> identifies copyright statements in a string
and serializes them in a normalized format.

=head1 OPTIONS

Options can be set as an argument to the 'use' statement.

=head2 threshold, threshold_before, threshold_after

    use String::Copyright { threshold_after => 5 };

Stop parsing after this many lines without copyright information,
before or after having found any copyright information at all.
C<threshold> sets both C<threshold_before> and C<threshold_after>.

By default unset: All lines are parsed.

=head2 format( \&sub )

    use String::Copyright { format => \&GNU_style } };

    sub GNU_style {
        my ( $years, $owners ) = @_;

        return 'Copyright (C) ' . join '  ', $years || '', $owners || '';
    }

=head1 FUNCTIONS

Exports one function: C<copyright>.
This module uses L<Exporter::Tiny> to export functions,
which allows for flexible import options;
see the L<Exporter::Tiny> documentation for details.

=cut

my $html_xml_tags_re = qr/<\/?(?:p|br|ref)(?:\s[^>]*)?>/i;

# OR'ed strings have regular variable name and are already grouped
# AND'ed strings have name ending in underscore: must be grouped if repeated
my $blank           = '[ \t]';
my $blank_or_break_ = "$blank*\\n?$blank*";
my $colons_         = "$blank?:{1,2}";
my $strictlabel     = 'SPDX-FileCopyrightText:';
my $label           = '(?i:copyright(?:-holders?)?\b|copr\.)';
my $sign            = '[©⒞Ⓒⓒ🄒🄫🅒]';
my $nroff_sign_     = '\\\\[(]co';
my $pseudo_sign_    = '[({][Cc][})]';
my $vague_sign_     = '-[Cc]-';
my $broken_sign_    = "\\?$blank*";

my @dash_codepoints = (
	'002D',    # U+002D HYPHEN-MINUS
	'02D7',    # U+02D7 MODIFIER LETTER MINUS SIGN
	'2010',    # U+2010 HYPHEN
	'2011',    # U+2011 NON-BREAKING HYPHEN
	'2012',    # U+2012 FIGURE DASH
	'2013',    # U+2013 EN DASH
	'2014',    # U+2014 EM DASH
	'2015',    # U+2015 HORIZONTAL BAR
	'2043',    # U+2043 HYPHEN BULLET
	'2212',    # U+2212 MINUS SIGN
	'FE63',    # U+FE63 SMALL HYPHEN-MINUS
	'FF0D',    # U+FF0D FULLWIDTH HYPHEN-MINUS
);

my $dash = '[' . join( '', map { chr( hex($_) ) } @dash_codepoints ) . '-]';

my %soup_patterns = (
	"\xC2\xA9" => 'UTF-8 © (C2 A9) mis-read as two latin1 chars "Â©"',
	"\xA1\xA4" =>
		'EUC-JP © (JIS X 0208 row 01 col 01), read as latin1 as "¡¤"',
	"\x81\x98" => 'Shift-JIS / CP932 ©, read as latin1 as two C1 controls',
	"\xA2\xA9" => 'GBK © (Chinese, code page 936), read as latin1 as "¢©"',
);

my %dash_soup = (
	"\x{E2}\x{80}\x{93}"       => 'EN-DASH (UTF-8 as Latin-1)',
	"\x{E2}\x{80}\x{94}"       => 'EM-DASH (UTF-8 as Latin-1)',
	"\x{E2}\x{20AC}\x{201C}"   => 'EN-DASH (UTF-8 as CP1252)',
	"\x{E2}\x{20AC}\x{201D}"   => 'EM-DASH (UTF-8 as CP1252)',
	"\x{0432}\x{0402}\x{2019}" => 'EN-DASH (UTF-8 as CP1251)',
	"\x{0432}\x{0402}\x{201D}" => 'EM-DASH (UTF-8 as CP1251)',
);

my $_build_alt = sub ($table) {
	my @alt;
	for my $pat ( sort { length $b <=> length $a } keys %$table ) {
		my $esc = join '',
			map { '\x{' . sprintf( '%X', ord ) . '}' } split //, $pat;
		push @alt, $esc;
	}
	return join '|', @alt;
};
my $sign_soup_ = $_build_alt->( \%soup_patterns );
my $dash_soup_ = $_build_alt->( \%dash_soup );

# high-bit © noise, caused by misparsing UTF-8 as latin1
# except \xA2 (GBK © lead byte ¢©), \xAE (latin1 ©), \xAE (MacRoman ©)
# and \xE2 (latin1 © lowercased after misparse)
my $nonsign_ = '[\x80-\xA1\xA3-\xAB\xAD-\xC1\xC3-\xE1\xE3-\xFF]\xA9';
my $nonidentifier_
	= "(?:no |_|$dash)copyright|copyright-[^h]|(?:Digital Millennium|U.S.|US|United States) Copyright Act|\\b(?:for|we) copyright\\b";

# this should cause *no* false positives, and stop-chars therefore
# exclude e.g. email address building blocks; tested against the code
# corpus at https://codesearch.debian.net/ (tricky: its RE2 engine lacks
# support for negative groups) using searches like these:
# (?i)copyright (?:(?:claim|holder|info|information|notice|owner|ownership|statement|string)s?|in|is|to)@\w
# (?i)copyright (?:(?:claim|holder|info|information|notice|owner|ownership|statement|string)s?|in|is|to)@\b[-_@]
# (?im)copyright (?:(?:claim|holder|info|information|notice|owner|ownership|statement|string)s?|in|is|to)[^ $]
my $identifier_action
	= '(?i:apply|applied|applies|assigned|generated|transfer|transferred)';
my $identifier_thing_
	= '(?i:block|claim|date|disclaimer|holder|info|information|interest|law|license|notice|owner|ownership|permission|sign|statement|string|symbol|tag|text)s?';
my $identifier_misc
	= "(?i:and|are|at|eq|for|if|in|is|of|on|or|,${blank}patent|this|to|the (?:library|software),|treaty)";
my $identifier_chatter
	= "(?:$identifier_action|$identifier_thing_|$identifier_misc)";
my $the_notname
	= '(?i:concrete|fault|first|immediately|least|min\/max|one|outer|previous|ratio|sum|user)';
my $the_sentence_
	= "(?:\\w+$blank+){1,10}(?i:are|can(?:not)?|in|is|must|was)";
my $pseudosign_chatter_
	= "(?:(?:the$blank+(?:$the_notname|$the_sentence_)|all begin|there|you must)\\b|,? \\(?\\w\\))";
my $chatter
	= "(?im:$nonsign_|$nonidentifier_|copyright$blank_or_break_$identifier_chatter(?:\\z|@\\W|[^a-zA-Z0-9@_-])|$blank*$pseudo_sign_(?:$blank_or_break_)+$pseudosign_chatter_)";
my $nonyears_ = '\W?(?i:year|19[xy]{2}|[xy]{4})\W?';

my $year_       = '\b[0-9]{4}\b';
my $comma_spacy = "(?:$blank*,$blank_or_break_|$blank_or_break_,?$blank*)";
my $dash_spacy_ = "$blank*$dash(?:$blank_or_break_)*";

my $colon_or_dash = "(?:$colons_$blank_or_break_|$blank?$dash\{1,2}$blank)";
my $delimiter     = "(?:$colon_or_dash|$comma_spacy)";

my $vague_year_ = "(?:$dash$blank?)?[0-9]{1,5}";
my $owner_intro_
	= "(?:$colon_or_dash|$pseudo_sign_$blank?|\\bby$blank_or_break_)";
my $owner_prefix  = '[(*<@\[{]';
my $owner_initial = '[^\s!"#$%&\'()*+,./:;<=>?@[\\\\\]^_`{|}~-]';

my $signs
	= "(?m:$strictlabel$blank*|(?:$label|$sign|$nroff_sign_|(?:^|$blank)$pseudo_sign_)(?:$colon_or_dash?$blank*(?:$label|$sign|$pseudo_sign_))*)";

my $yearspan_ = "$year_(?:$dash_spacy_$year_)?";
my $years_    = "$yearspan_(?:$comma_spacy$yearspan_)*";
my $owners_
	= "(?:$vague_year_|$owner_prefix*$owner_initial\\S*)(?:$blank*\\S+)*";

# compile regexps in isolation to limit use of RE2 engine
my ($dash_spacy_re, $owner_intro_A_re, $boilerplate_X_re,
	$signs_and_more_re
);
{
	BEGIN { re::engine::RE2->import( -strict => 1 ) if ($CAN_RE2) }
	$dash_spacy_re    = qr/$dash_spacy_/;
	$owner_intro_A_re = qr/^$owner_intro_/;
	$boilerplate_X_re
		= qr/(?i)${comma_spacy}All$blank+Rights$blank+Reserved[.!]?.*/;
	$signs_and_more_re
		= qr/$chatter|$signs(?:$blank$vague_sign_)?$delimiter(?:$broken_sign_)?(?:$nonyears_|((?:$years_$delimiter)?(?:(?:$owner_intro_)?$owners_)?))|\n/;
}

sub _merge_ranges
{
	my @ranges = map { ref $_ ? [@$_] : [ $_, $_ ] } @_;
	@ranges = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @ranges;

	my @merged;
	for my $r (@ranges) {
		if ( @merged && $r->[0] <= $merged[-1][1] + 1 ) {
			$merged[-1][1] = $r->[1] if $r->[1] > $merged[-1][1];
		}
		else {
			push @merged, [@$r];
		}
	}
	return @merged;
}

sub _generate_copyright
{
	my ( $class, $name, $args, $globals ) = @_;

	return sub {
		my $copyright = shift;

		Carp::croak("String::Copyright strings require defined parts")
			unless 1 + @_ == grep {defined} $copyright, @_;

	   # String::Copyright objects are effectively immutable and can be reused
		if ( !@_ && blessed($copyright) ) {
			return $copyright;
		}

		# stringify objects
		$copyright = "$copyright";

		my %changed;

		my $pre = $copyright;

		if ( my $c = $copyright =~ s{$html_xml_tags_re}{}g ) {
			$changed{html} = $c;
		}

		if ( my $c = $copyright =~ s/$dash_soup_/-/g ) {
			$changed{dash_soup} = $c;
		}

		if ( $copyright =~ /(?:$sign)|(?i:copyright\b)/ ) {
			if ( my $c = $copyright =~ s/$sign_soup_/©/g ) {
				$changed{sign_soup} = $c;
			}
		}

		if ( ( my $c = $copyright =~ s/$dash/-/g ) ) {
			$changed{dash} = $c;
			if ( $log->is_trace ) {
				my %seen;
				my @notes;
				while ( $pre =~ /[$dash]/g ) {
					my $cp = ord $&;
					next if $cp == 0x2D;
					next if $seen{$cp}++;
					push @notes, sprintf( 'U+%04X', $cp );
				}
				$changed{dash} = \@notes if @notes;
			}
		}

		if (%changed) {
			if ( $log->is_trace ) {
				$log->trace( 'normalized copyright string', \%changed );
			}
			else {
				$log->debugf(
					'normalized copyright string: %s',
					join( ', ', sort keys %changed )
				);
			}
		}

		# TODO: also parse @_ - but each separately!
		my @block;
		my $skipped = 0;
		while ( $copyright =~ /$signs_and_more_re/g ) {

			my $owners = $1;
			if ( $globals->{threshold_before} || $globals->{threshold} ) {
				last
					if (
						!@block
					and !length $owners
					and ++$skipped >= (
						$globals->{threshold_before} || $globals->{threshold}
					)
					);
			}
			if ( $globals->{threshold_after} || $globals->{threshold} ) {

				# "after" detects end of _current_ line so is skewed by one
				last
					if (
						@block
					and !length $owners
					and ++$skipped >= 1 + (
						$globals->{threshold_after} || $globals->{threshold}
					)
					);
			}
			next if ( !length $owners );
			$skipped = 0;

			my $years;
			my @span = $owners =~ /\G($yearspan_)(?:$comma_spacy|\Z)/gm;
			if (@span) {
				$owners = $';

				# deduplicate
				my @ranges;
				for (@span) {
					my ( $y1, $y2 ) = split /$dash_spacy_re/;
					if    ( !$y2 )      { push @ranges, $y1; }
					elsif ( $y1 > $y2 ) { push @ranges, [ $y2, $y1 ]; }
					else                { push @ranges, [ $y1, $y2 ]; }
				}

				# normalize
				$years = join ', ',
					map { $_->[0] == $_->[1] ? $_->[0] : "$_->[0]-$_->[1]" }
					_merge_ranges(@ranges);
			}
			if ($owners) {
				$owners =~ s/$owner_intro_A_re//;
				$owners =~ s/\s{2,}/ /g;
				$owners =~ s/$owner_intro_A_re//;
				$owners =~ s/$boilerplate_X_re//g;
			}

# split owner into owner_id and owner

			push @block, [ $years || undef, $owners || undef ];
		}

# TODO: save $skipped to indicate how dirty parsing was

		my $ext_format = $globals->{format};
		my $format
			= $globals->{format}
			? sub { $ext_format->( $_->[0], $_->[1] ) }
			: sub { join ' ', '©', $_->[0] || (), $_->[1] || () };

		bless [ $copyright, \@block, $format ], __PACKAGE__;
	};
}

sub new
{
	my ( $self, @data ) = @_;
	Carp::croak("String::Copyright require defined, positive-length parts")
		unless 1 + @_ == grep { defined && length } @data;

	# String::Copyright objects are simply stripped of their string part
	if ( !@_ && blessed($self) ) {
		return bless [ undef, $data[1] ], __PACKAGE__;
	}

	# FIXME: properly validate data
	Carp::croak("String::Copyright blocks must be an array of strings")
		unless @_ == grep { reftype($_) eq 'ARRAY' } @data;

	bless [ undef, \@data ], __PACKAGE__;
}

sub _compose
{
	my $format = $_[0]->[FORMAT];
	join "\n", map {&$format} @{ $_[0]->[BLOCKS] };
}

sub is_normalized { !defined $_[0]->[PLAINTEXT] }

=head1 SEE ALSO

=over 4

=item *

L<Encode>

=item *

L<Exporter::Tiny>

=back

=head1 BUGS/CAVEATS/etc

L<String::Copyright> operates on strings, not bytes.
Data encoded as UTF-8, Latin1 or other formats
need to be decoded to strings before use.

Only ASCII characters and B<©> (copyright sign) are directly processed.

If copyright sign is not detected
or accents or multi-byte characters display wrong,
then most likely the data was not decoded into a string.

Some common mis-decoded forms of the copyright sign are recognized and
normalized to B<©> (e.g. UTF-8 read as Latin1, EUC-JP, Shift-JIS/CP932,
and GBK). When this happens a warning is emitted via L<Log::Any>.

If ranges or lists of years are not tidied,
then maybe it contained non-ASCII whitespace or digits.

=head1 AUTHOR

Jonas Smedegaard C<< <dr@jones.dk> >>

=head1 COPYRIGHT AND LICENSE

This program is based on the script "licensecheck" from the KDE SDK,
originally introduced by Stefan Westerfeld C<< <stefan@space.twc.de> >>.

  Copyright © 2007, 2008 Adam D. Barratt

  Copyright © 2005-2012, 2016, 2018, 2020-2021 Jonas Smedegaard

  Copyright © 2018, 2020-2021 Purism SPC

This program is free software:
you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License
as published by the Free Software Foundation,
either version 3, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY;
without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Affero General Public License for more details.

You should have received a copy
of the GNU Affero General Public License along with this program.
If not, see <https://www.gnu.org/licenses/>.

=cut

1;
