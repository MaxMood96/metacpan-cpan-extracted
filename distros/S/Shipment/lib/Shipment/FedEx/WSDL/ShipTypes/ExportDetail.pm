package Shipment::FedEx::WSDL::ShipTypes::ExportDetail;
$Shipment::FedEx::WSDL::ShipTypes::ExportDetail::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://fedex.com/ws/ship/v9' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %B13AFilingOption_of :ATTR(:get<B13AFilingOption>);
my %ExportComplianceStatement_of :ATTR(:get<ExportComplianceStatement>);
my %PermitNumber_of :ATTR(:get<PermitNumber>);
my %DestinationControlDetail_of :ATTR(:get<DestinationControlDetail>);

__PACKAGE__->_factory(
    [ qw(        B13AFilingOption
        ExportComplianceStatement
        PermitNumber
        DestinationControlDetail

    ) ],
    {
        'B13AFilingOption' => \%B13AFilingOption_of,
        'ExportComplianceStatement' => \%ExportComplianceStatement_of,
        'PermitNumber' => \%PermitNumber_of,
        'DestinationControlDetail' => \%DestinationControlDetail_of,
    },
    {
        'B13AFilingOption' => 'Shipment::FedEx::WSDL::ShipTypes::B13AFilingOptionType',
        'ExportComplianceStatement' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'PermitNumber' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'DestinationControlDetail' => 'Shipment::FedEx::WSDL::ShipTypes::DestinationControlDetail',
    },
    {

        'B13AFilingOption' => 'B13AFilingOption',
        'ExportComplianceStatement' => 'ExportComplianceStatement',
        'PermitNumber' => 'PermitNumber',
        'DestinationControlDetail' => 'DestinationControlDetail',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::FedEx::WSDL::ShipTypes::ExportDetail

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
ExportDetail from the namespace http://fedex.com/ws/ship/v9.

Country specific details of an International shipment.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * B13AFilingOption (min/maxOccurs: 0/1)

=item * ExportComplianceStatement (min/maxOccurs: 0/1)

=item * PermitNumber (min/maxOccurs: 0/1)

=item * DestinationControlDetail (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::FedEx::WSDL::ShipTypes::ExportDetail

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::FedEx::WSDL::ShipTypes::ExportDetail
   B13AFilingOption => $some_value, # B13AFilingOptionType
   ExportComplianceStatement =>  $some_value, # string
   PermitNumber =>  $some_value, # string
   DestinationControlDetail =>  { # Shipment::FedEx::WSDL::ShipTypes::DestinationControlDetail
     StatementTypes => $some_value, # DestinationControlStatementType
     DestinationCountries =>  $some_value, # string
     EndUser =>  $some_value, # string
   },
 },

=head1 AUTHOR

Generated by SOAP::WSDL

=head1 AUTHOR

Andrew Baerg <baergaj@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Andrew Baerg.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
