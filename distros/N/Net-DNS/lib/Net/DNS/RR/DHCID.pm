package Net::DNS::RR::DHCID;

use strict;
use warnings;
our $VERSION = (qw$Id: DHCID.pm 2003 2025-01-21 12:06:06Z willem $)[2];

use base qw(Net::DNS::RR);


=head1 NAME

Net::DNS::RR::DHCID - DNS DHCID resource record

=cut

use integer;

use MIME::Base64;


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my @rdata = split /\s+/, encode_base64( $self->_encode_rdata );
	return @rdata;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my ( $self, @argument ) = @_;

	$self->rdata( MIME::Base64::decode( join "", @argument ) );
	return;
}


#	+------------------+------------------------------------------------+
#	|  Identifier Type | Identifier					    |
#	|	Code	   |						    |
#	+------------------+------------------------------------------------+
#	|      0x0000	   | The 1-octet 'htype' followed by 'hlen' octets  |
#	|		   | of 'chaddr' from a DHCPv4 client's DHCPREQUEST |
#	|		   | [7].					    |
#	|      0x0001	   | The data octets (i.e., the Type and	    |
#	|		   | Client-Identifier fields) from a DHCPv4	    |
#	|		   | client's Client Identifier option [10].	    |
#	|      0x0002	   | The client's DUID (i.e., the data octets of a  |
#	|		   | DHCPv6 client's Client Identifier option [11]  |
#	|		   | or the DUID field from a DHCPv4 client's	    |
#	|		   | Client Identifier option [6]).		    |
#	|  0x0003 - 0xfffe | Undefined; available to be assigned by IANA.   |
#	|      0xffff	   | Undefined; RESERVED.			    |
#	+------------------+------------------------------------------------+

sub identifiertype { return unpack 'n', shift->{rdata} || return }

sub digesttype { return unpack 'x2C', shift->{rdata} || return }

sub digest { return unpack 'x3a*', shift->{rdata} || return }


1;
__END__


=head1 SYNOPSIS

	use Net::DNS;
	$rr = Net::DNS::RR->new('client.example.com. DHCID ( AAAB
		xLmlskllE0MVjd57zHcWmEH3pCQ6VytcKD//7es/deY= )');

	$rr = Net::DNS::RR->new(
		name		=> 'client.example.com',
		type		=> 'DHCID',
		digest		=> 'ObfuscatedIdentityData',
		digesttype	=> 1,
		identifiertype	=> 2,
		);

=head1 DESCRIPTION

DNS RR for Encoding DHCP Information (DHCID)

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 identifiertype

	$identifiertype = $rr->identifiertype;

The 16-bit identifier type describes the form of host identifier
used to construct the DHCP identity information.


=head2 digesttype

	$digesttype = $rr->digesttype;

The 8-bit digest type number describes the message-digest
algorithm used to obfuscate the DHCP identity information.


=head2 digest

	$digest = $rr->digest;

Binary representation of the digest of DHCP identity information.


=head1 COPYRIGHT

Copyright (c)2009 Olaf Kolkman, NLnet Labs.

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
L<RFC4701|https://iana.org/go/rfc4701>

=cut
