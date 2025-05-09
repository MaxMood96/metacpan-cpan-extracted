package Net::RDAP::Variant;
use Net::RDAP::VariantName;
use strict;
use warnings;

=pod

=head1 NAME

L<Net::RDAP::Variant> - a module representing one or more variants of a domain
name.

=head1 DESCRIPTION

Internationalized Domain Names (IDNs) may (depending on the script and/or
language they are written in) have variant names. For example, a name written in
Simplified Chinese may have a variant in Traditional Chinese, and vice versa.

The C<variants()> property of L<Net::RDAP::Domain> objects may return an array
of L<Net::RDAP::Variant> objects representing such variant names.

=cut

sub new {
    my ($package, $ref) = @_;
    return bless($ref, $package);
};

=pod

=head1 METHODS

    @relation = $variant->relation;

Returns an array of strings describing the relationship between the variants.
This array B<SHOULD> only contain values that are present in the IANA registry
(see L<Net::RDAP::Values>).

=cut

sub relation { @{ $_[0]->{'relation'} || [] } }

=pod

    $table = $variant->idnTable;

Returns a string that represents the Internationalized Domain Name (IDN) table
that has been registered in the
L<IANA Repository of IDN Practices|https://www.iana.org/domains/idn-tables>.

=cut

sub idnTable { $_[0]->{'idnTable'} }

=pod

    @names = $variant->variantNames;

Returns an array of L<Net::RDAP::VariantName> objects.

=cut

sub variantNames { map { Net::RDAP::VariantName->new($_) } @{ $_[0]->{'variantNames'} || [] } }

=pod

=head1 COPYRIGHT

Copyright 2018-2023 CentralNic Ltd, 2024-2025 Gavin Brown. For licensing information,
please see the C<LICENSE> file in the L<Net::RDAP> distribution.

=cut

1;
