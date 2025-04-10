package Net::DNS::RR::NSEC3PARAM;

use strict;
use warnings;
our $VERSION = (qw$Id: NSEC3PARAM.pm 2003 2025-01-21 12:06:06Z willem $)[2];

use base qw(Net::DNS::RR);


=head1 NAME

Net::DNS::RR::NSEC3PARAM - DNS NSEC3PARAM resource record

=cut

use integer;

use Carp;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my ( $self, $data, $offset ) = @_;

	my $size = unpack "\@$offset x4 C", $$data;
	@{$self}{qw(algorithm flags iterations saltbin)} = unpack "\@$offset CCnx a$size", $$data;
	return;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $salt = $self->saltbin;
	return pack 'CCnCa*', @{$self}{qw(algorithm flags iterations)}, length($salt), $salt;
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return join ' ', $self->algorithm, $self->flags, $self->iterations, $self->salt || '-';
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my ( $self, @argument ) = @_;

	for (qw(algorithm flags iterations)) { $self->$_( shift @argument ) }
	my $salt = shift @argument;
	$self->salt($salt) unless $salt eq '-';
	return;
}


sub algorithm {
	my ( $self, @value ) = @_;
	for (@value) { $self->{algorithm} = 0 + $_ }
	return $self->{algorithm} || 0;
}


sub flags {
	my ( $self, @value ) = @_;
	for (@value) { $self->{flags} = 0 + $_ }
	return $self->{flags} || 0;
}


sub iterations {
	my ( $self, @value ) = @_;
	for (@value) { $self->{iterations} = 0 + $_ }
	return $self->{iterations} || 0;
}


sub salt {
	my ( $self, @value ) = @_;
	return unpack "H*", $self->saltbin() unless scalar @value;
	my @hex = map { /^"*([\dA-Fa-f]*)"*$/ || croak("corrupt hex"); $1 } @value;
	return $self->saltbin( pack "H*", join "", @hex );
}


sub saltbin {
	my ( $self, @value ) = @_;
	for (@value) { $self->{saltbin} = $_ }
	return $self->{saltbin} || "";
}


########################################

sub hashalgo { return &algorithm; }				# uncoverable pod

########################################


1;
__END__


=head1 SYNOPSIS

	use Net::DNS;
	$rr = Net::DNS::RR->new('name NSEC3PARAM algorithm flags iterations salt');

=head1 DESCRIPTION

Class for DNSSEC NSEC3PARAM resource records.

The NSEC3PARAM RR contains the NSEC3 parameters (hash algorithm,
flags, iterations and salt) needed to calculate hashed ownernames.

The presence of an NSEC3PARAM RR at a zone apex indicates that the
specified parameters may be used by authoritative servers to choose
an appropriate set of NSEC3 records for negative responses.

The NSEC3PARAM RR is not used by validators or resolvers.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 algorithm

	$algorithm = $rr->algorithm;
	$rr->algorithm( $algorithm );

The 8-bit algorithm field is represented as an unsigned decimal integer. 

=head2 flags

	$flags = $rr->flags;
	$rr->flags( $flags );

The Flags field is an unsigned decimal integer
interpreted as eight concatenated Boolean values. 

=head2 iterations

	$iterations = $rr->iterations;
	$rr->iterations( $iterations );

The Iterations field is represented as an unsigned decimal
integer.  The value is between 0 and 65535, inclusive. 

=head2 salt

	$salt = $rr->salt;
	$rr->salt( $salt );

The Salt field is represented as a contiguous sequence of hexadecimal
digits. A "-" (unquoted) is used in string format to indicate that the
salt field is absent. 

=head2 saltbin

	$saltbin = $rr->saltbin;
	$rr->saltbin( $saltbin );

The Salt field as a sequence of octets. 


=head1 COPYRIGHT

Copyright (c)2007,2008 NLnet Labs.  Author Olaf M. Kolkman

All rights reserved.

Package template (c)2009,2012 O.M.Kolkman and R.W.Franks.


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

L<perl> L<Net::DNS> L<Net::DNS::RR>
L<RFC5155(4)|https://iana.org/go/rfc5155#section-4>

=cut
