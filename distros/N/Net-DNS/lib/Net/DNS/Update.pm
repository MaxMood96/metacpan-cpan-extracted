package Net::DNS::Update;

use strict;
use warnings;

our $VERSION = (qw$Id: Update.pm 2017 2025-06-27 13:48:03Z willem $)[2];


=head1 NAME

Net::DNS::Update - DNS dynamic update packet

=head1 SYNOPSIS

	use Net::DNS;

	$update = Net::DNS::Update->new( 'example.com', 'IN' );

	$update->push( prereq => nxrrset('host.example.com. AAAA') );
	$update->push( update => rr_add('host.example.com. 86400 AAAA 2001::DB8::F00') );

=head1 DESCRIPTION

Net::DNS::Update is a subclass of Net::DNS::Packet, to be used for
making DNS dynamic updates.

Programmers should refer to RFC2136 for dynamic update semantics.

=cut


use integer;
use Carp;

use base qw(Net::DNS::Packet);

use Net::DNS::Resolver;


=head1 METHODS

=head2 new

	$update = Net::DNS::Update->new;
	$update = Net::DNS::Update->new( 'example.com' );
	$update = Net::DNS::Update->new( 'example.com', 'IN' );

Returns a Net::DNS::Update object suitable for performing a DNS
dynamic update.	 Specifically, it creates a packet with the header
opcode set to UPDATE and the zone record type to SOA (per RFC 2136,
Section 2.3).

Programs must use the push() method to add RRs to the prerequisite
and update sections before performing the update.

Arguments are the zone name and the class.  The zone and class may
be undefined or omitted and default to the default domain from the
resolver configuration and IN respectively.

=cut

sub new {
	my ( $class, $zone, @rrclass ) = @_;

	my ($domain) = grep { defined && length } ( $zone, Net::DNS::Resolver->searchlist );

	my $self = __PACKAGE__->SUPER::new( $domain, 'SOA', @rrclass );

	my $header = $self->header;
	$header->opcode('UPDATE');
	$header->qr(0);
	$header->rd(0);

	return $self;
}


=head2 push

	$ancount = $update->push( prereq => $rr );
	$nscount = $update->push( update => $rr );
	$arcount = $update->push( additional => $rr );

	$nscount = $update->push( update => $rr1, $rr2, $rr3 );
	$nscount = $update->push( update => @rr );

Adds RRs to the specified section of the update packet.

Returns the number of resource records in the specified section.

Section names may be abbreviated to the first three characters.

=cut

sub push {
	my ( $self, $section, @rr ) = @_;
	my ($zone) = $self->zone;
	my $zclass = $zone->zclass;
	for (@rr) { $_->class( $_->class =~ /ANY|NONE/ ? () : $zclass ) }
	return $self->SUPER::push( $section, @rr );
}


=head2 unique_push

	$ancount = $update->unique_push( prereq => $rr );
	$nscount = $update->unique_push( update => $rr );
	$arcount = $update->unique_push( additional => $rr );

	$nscount = $update->unique_push( update => $rr1, $rr2, $rr3 );
	$nscount = $update->unique_push( update => @rr );

Adds RRs to the specified section of the update packet provided
that the RRs are not already present in the same section.

Returns the number of resource records in the specified section.

Section names may be abbreviated to the first three characters.

=cut

sub unique_push {
	my ( $self, $section, @rr ) = @_;
	my ($zone) = $self->zone;
	my $zclass = $zone->zclass;
	for (@rr) { $_->class( $_->class =~ /ANY|NONE/ ? () : $zclass ) }
	return $self->SUPER::unique_push( $section, @rr );
}


1;

__END__


=head1 EXAMPLES

The first example below shows a complete program.
Subsequent examples show only the creation of the update packet.

Although the examples are presented using the string form of RRs,
the corresponding ( name => value ) form may also be used.

=head2 Add a new host

	#!/usr/bin/perl

	use Net::DNS;

	# Create the update packet.
	my $update = Net::DNS::Update->new('example.com');

	# Prerequisite is that no address records exist for the name.
	$update->push( pre => nxrrset('host.example.com. A') );
	$update->push( pre => nxrrset('host.example.com. AAAA') );

	# Add two address records for the name.
	$update->push( update => rr_add('host.example.com. 86400 A 192.0.2.1') );
	$update->push( update => rr_add('host.example.com. 86400 AAAA 2001:DB8::1') );

	# Send the update to the zone's primary nameserver.
	my $resolver = Net::DNS::Resolver->new();
	$resolver->nameservers('DNSprimary.example.com');

	my $reply = $resolver->send($update);

	# Did it work?
	if ($reply) {
		print 'Update RCODE: ', $reply->header->rcode, "\n";
	} else {
		print 'Update failed: ', $resolver->errorstring, "\n";
	}


=head2 Add an MX record for a name that already exists

	my $update = Net::DNS::Update->new('example.com');
	$update->push( prereq => yxdomain('example.com') );
	$update->push( update => rr_add('example.com MX 10 mailhost.example.com') );

=head2 Add a TXT record for a name that does not exist

	my $update = Net::DNS::Update->new('example.com');
	$update->push( prereq => nxdomain('info.example.com') );
	$update->push( update => rr_add('info.example.com TXT "yabba dabba doo"') );

=head2 Delete all A records for a name

	my $update = Net::DNS::Update->new('example.com');
	$update->push( prereq => yxrrset('host.example.com A') );
	$update->push( update => rr_del('host.example.com A') );

=head2 Delete all RRs for a name

	my $update = Net::DNS::Update->new('example.com');
	$update->push( prereq => yxdomain('byebye.example.com') );
	$update->push( update => rr_del('byebye.example.com') );

=head2 Perform DNS update signed using a key generated by BIND tsig-keygen

	my $update = Net::DNS::Update->new('example.com');
	$update->push( update => rr_add('host.example.com AAAA 2001:DB8::1') );
	$update->sign_tsig( $key_file );
	my $reply = $resolver->send( $update );
	$reply->verify( $update ) || die $reply->verifyerr;

=head2 Signing the DNS update using a customised TSIG record

	$update->sign_tsig( $key_file, fudge => 60 );

=head2 Another way to sign a DNS update

	use Net::DNS::RR::TSIG;

	my $tsig = create Net::DNS::RR::TSIG( $key_file );
	$tsig->fudge(60);

	my $update = Net::DNS::Update->new('example.com');
	$update->push( update     => rr_add('host.example.com AAAA 2001:DB8::1') );
	$update->push( additional => $tsig );


=head1 COPYRIGHT

Copyright (c)1997-2000 Michael Fuhr. 

Portions Copyright (c)2002,2003 Chris Reinhardt.

Portions Copyright (c)2015 Dick Franks.

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

L<perl> L<Net::DNS> L<Net::DNS::Packet> L<Net::DNS::Header>
L<Net::DNS::RR> L<Net::DNS::Resolver>
L<RFC2136|https://iana.org/go/rfc2136>
L<RFC8945|https://iana.org/go/rfc8945>

=cut

