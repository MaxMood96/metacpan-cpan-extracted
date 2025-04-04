package Net::DNS::Domain;

use strict;
use warnings;

our $VERSION = (qw$Id: Domain.pm 2002 2025-01-07 09:57:46Z willem $)[2];


=head1 NAME

Net::DNS::Domain - DNS domains

=head1 SYNOPSIS

	use Net::DNS::Domain;

	$domain = Net::DNS::Domain->new('example.com');
	$name   = $domain->name;

=head1 DESCRIPTION

The Net::DNS::Domain module implements a class of abstract DNS
domain objects with associated class and instance methods.

Each domain object instance represents a single DNS domain which
has a fixed identity throughout its lifetime.

Internally, the primary representation is a (possibly empty) list
of ASCII domain name labels, and optional link to an origin domain
object topologically closer to the DNS root.

The computational expense of Unicode character-set conversion is
partially mitigated by use of caches.

=cut


use integer;
use Carp;


use constant ASCII => ref eval {
	require Encode;
	Encode::find_encoding('ascii');
};

use constant UTF8 => scalar eval {	## not UTF-EBCDIC  [see Unicode TR#16 3.6]
	Encode::encode_utf8( chr(182) ) eq pack( 'H*', 'C2B6' );
};

use constant LIBIDN2  => defined eval { require Net::LibIDN2 };
use constant IDN2FLAG => LIBIDN2 ? &Net::LibIDN2::IDN2_NFC_INPUT + &Net::LibIDN2::IDN2_NONTRANSITIONAL : 0;
use constant LIBIDN   => LIBIDN2 ? undef : defined eval { require Net::LibIDN };

# perlcc: address of encoding objects must be determined at runtime
my $ascii = ASCII ? Encode::find_encoding('ascii') : undef;	# Osborn's Law:
my $utf8  = UTF8  ? Encode::find_encoding('utf8')  : undef;	# Variables won't; constants aren't.


=head1 METHODS

=head2 new

	$object = Net::DNS::Domain->new('example.com');

Creates a domain object which represents the DNS domain specified
by the character string argument. The argument consists of a
sequence of labels delimited by dots.

A character preceded by \ represents itself, without any special
interpretation.

Arbitrary 8-bit codes can be represented by \ followed by exactly
three decimal digits.
Character code points are ASCII, irrespective of the character
coding scheme employed by the underlying platform.

Argument string literals should be delimited by single quotes to
avoid escape sequences being interpreted as octal character codes
by the Perl compiler.

The character string presentation format follows the conventions
for zone files described in RFC1035.

Users should be aware that non-ASCII domain names will be transcoded
to NFC before encoding, which is an irreversible process.

=cut

my ( %escape, %unescape );		## precalculated ASCII escape tables

our $ORIGIN;
my ( $cache1, $cache2, $limit ) = ( {}, {}, 100 );

sub new {
	my ( $class, $s ) = @_;
	croak 'domain identifier undefined' unless defined $s;

	my $index = join '', $s, $class, $ORIGIN || '';		# cache key
	my $cache = $$cache1{$index} ||= $$cache2{$index};	# two layer cache
	return $cache if defined $cache;

	( $cache1, $cache2, $limit ) = ( {}, $cache1, 500 ) unless $limit--;	# recycle cache

	my $self = bless {}, $class;

	$s =~ s/\\\\/\\092/g;					# disguise escaped escape
	$s =~ s/\\\./\\046/g;					# disguise escaped dot

	my $label = $self->{label} = ( $s eq '@' ) ? [] : [split /\056/, _encode_utf8($s)];

	foreach (@$label) {
		croak qq(empty label in "$s") unless length;

		if ( LIBIDN2 && UTF8 && /[^\000-\177]/ ) {
			my $rc = 0;
			$_ = Net::LibIDN2::idn2_to_ascii_8( $_, IDN2FLAG, $rc );
			croak Net::LibIDN2::idn2_strerror($rc) unless $_;
		}

		if ( LIBIDN && UTF8 && /[^\000-\177]/ ) {
			$_ = Net::LibIDN::idn_to_ascii( $_, 'utf-8' );
			croak 'name contains disallowed character' unless $_;
		}

		s/\134([\060-\071]{3})/$unescape{$1}/eg;	# restore numeric escapes
		s/\134([^\134])/$1/g;				# restore character escapes
		s/\134(\134)/$1/g;				# restore escaped escapes
		croak qq(label too long in "$s") if length > 63;
	}

	$$cache1{$index} = $self;				# cache object reference

	return $self if $s =~ /\.$/;				# fully qualified name
	$self->{origin} = $ORIGIN || return $self;		# dynamically scoped $ORIGIN
	return $self;
}


=head2 name

	$name = $domain->name;

Returns the domain name as a character string corresponding to the
"common interpretation" to which RFC1034, 3.1, paragraph 9 alludes.

Character escape sequences are used to represent a dot inside a
domain name label and the escape character itself.

Any non-printable code point is represented using the appropriate
numerical escape sequence.

=cut

sub name {
	my ($self) = @_;

	return $self->{name} if defined $self->{name};
	return unless defined wantarray;

	my @label = shift->_wire;
	return $self->{name} = '.' unless scalar @label;

	for (@label) {
		s/([^\055\101-\132\141-\172\060-\071])/$escape{$1}/eg;
	}

	return $self->{name} = _decode_ascii( join chr(46), @label );
}


=head2 fqdn

	$fqdn = $domain->fqdn;

Returns a character string containing the fully qualified domain
name, including the trailing dot.

=cut

sub fqdn {
	my $name = &name;
	return $name =~ /[.]$/ ? $name : "$name.";		# append trailing dot
}


=head2 xname

	$xname = $domain->xname;

Interprets an extended name containing Unicode domain name labels
encoded as Punycode A-labels.

If decoding is not possible, the ACE encoded name is returned.

=cut

sub xname {
	my $name = &name;

	if ( LIBIDN2 && UTF8 && $name =~ /xn--/i ) {
		my $self = shift;
		return $self->{xname} if defined $self->{xname};
		my $u8 = Net::LibIDN2::idn2_to_unicode_88($name);
		return $self->{xname} = $u8 ? $utf8->decode($u8) : $name;
	}

	if ( LIBIDN && UTF8 && $name =~ /xn--/i ) {
		my $self = shift;
		return $self->{xname} if defined $self->{xname};
		return $self->{xname} = $utf8->decode( Net::LibIDN::idn_to_unicode $name, 'utf-8' );
	}
	return $name;
}


=head2 label

	@label = $domain->label;

Identifies the domain by means of a list of domain labels.

=cut

sub label {
	my @label = shift->_wire;
	for (@label) {
		s/([^\055\101-\132\141-\172\060-\071])/$escape{$1}/eg;
		_decode_ascii($_);
	}
	return @label;
}


=head2 string

	$string = $object->string;

Returns a character string containing the fully qualified domain
name as it appears in a zone file.

Characters which are recognised by RFC1035 zone file syntax are
represented by the appropriate escape sequence.

=cut

sub string { return &fqdn }


=head2 origin

	$create = Net::DNS::Domain->origin( $ORIGIN );
	$result = &$create( sub{ Net::DNS::RR->new( 'mx MX 10 a' ); } );
	$expect = Net::DNS::RR->new( "mx.$ORIGIN. MX 10 a.$ORIGIN." );

Class method which returns a reference to a subroutine wrapper
which executes a given constructor in a dynamically scoped context
where relative names become descendents of the specified $ORIGIN.

=cut

my $placebo = sub { my $constructor = shift; &$constructor; };

sub origin {
	my ( $class, $name ) = @_;
	my $domain = defined $name ? __PACKAGE__->new($name) : return $placebo;

	return sub {						# closure w.r.t. $domain
		my $constructor = shift;
		local $ORIGIN = $domain;			# dynamically scoped $ORIGIN
		&$constructor;
	}
}


########################################

sub _decode_ascii {			## ASCII to perl internal encoding
	local $_ = shift;

	# partial transliteration for non-ASCII character encodings
	tr
	[\040-\176\000-\377]
	[ !"#$%&'()*+,\-./0-9:;<=>?@A-Z\[\\\]^_`a-z{|}~?] unless ASCII;

	my $z = length($_) - length($_);			# pre-5.18 taint workaround
	return ASCII ? substr( $ascii->decode($_), $z ) : $_;
}


sub _encode_utf8 {			## perl internal encoding to UTF8
	local $_ = shift;

	# partial transliteration for non-ASCII character encodings
	tr
	[ !"#$%&'()*+,\-./0-9:;<=>?@A-Z\[\\\]^_`a-z{|}~\000-\377]
	[\040-\176\077] unless ASCII;

	my $z = length($_) - length($_);			# pre-5.18 taint workaround
	return ASCII ? substr( ( UTF8 ? $utf8 : $ascii )->encode($_), $z ) : $_;
}


sub _wire {
	my $self = shift;

	my $label  = $self->{label};
	my $origin = $self->{origin};
	return ( @$label, $origin ? $origin->_wire : () );
}


%escape = eval {			## precalculated ASCII escape table
	my %table = map { ( chr($_) => chr($_) ) } ( 0 .. 127 );

	foreach my $n ( 0 .. 32, 34, 92, 127 .. 255 ) {		# \ddd
		my $codepoint = sprintf( '%03u', $n );

		# transliteration for non-ASCII character encodings
		$codepoint =~ tr [0-9] [\060-\071];

		$table{pack( 'C', $n )} = pack 'C a3', 92, $codepoint;
	}

	foreach my $n ( 40, 41, 46, 59 ) {			# character escape
		$table{chr($n)} = pack( 'C2', 92, $n );
	}

	return %table;
};


%unescape = eval {			## precalculated numeric escape table
	my %table;

	foreach my $n ( 0 .. 255 ) {
		my $key = sprintf( '%03u', $n );

		# transliteration for non-ASCII character encodings
		$key =~ tr [0-9] [\060-\071];

		$table{$key} = pack 'C', $n;
	}
	$table{"\060\071\062"} = pack 'C2', 92, 92;		# escaped escape

	return %table;
};


1;
__END__


########################################

=head1 BUGS

Coding strategy is intended to avoid creating unnecessary argument
lists and stack frames. This improves efficiency at the expense of
code readability.

Platform specific character coding features are conditionally
compiled into the code.


=head1 COPYRIGHT

Copyright (c)2009-2011,2017 Dick Franks.

All rights reserved.


=head1 LICENSE

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted, provided
that the original copyright notices appear in all copies and that both
copyright notice and this permission notice appear in supporting
documentation, and that the name of the author not be used in advertising
or publicity pertaining to distribution of the software without specific
prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.


=head1 SEE ALSO

L<perl> L<Net::DNS> L<Net::LibIDN2>
L<RFC1034|https://iana.org/go/rfc1034>
L<RFC1035|https://iana.org/go/rfc1035>
L<RFC5891|https://iana.org/go/rfc5891>

=cut

