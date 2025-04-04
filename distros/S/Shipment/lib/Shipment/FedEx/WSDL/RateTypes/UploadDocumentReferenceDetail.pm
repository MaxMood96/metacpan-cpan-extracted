package Shipment::FedEx::WSDL::RateTypes::UploadDocumentReferenceDetail;
$Shipment::FedEx::WSDL::RateTypes::UploadDocumentReferenceDetail::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://fedex.com/ws/rate/v9' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %LineNumber_of :ATTR(:get<LineNumber>);
my %CustomerReference_of :ATTR(:get<CustomerReference>);
my %DocumentProducer_of :ATTR(:get<DocumentProducer>);
my %DocumentType_of :ATTR(:get<DocumentType>);
my %DocumentId_of :ATTR(:get<DocumentId>);
my %DocumentIdProducer_of :ATTR(:get<DocumentIdProducer>);

__PACKAGE__->_factory(
    [ qw(        LineNumber
        CustomerReference
        DocumentProducer
        DocumentType
        DocumentId
        DocumentIdProducer

    ) ],
    {
        'LineNumber' => \%LineNumber_of,
        'CustomerReference' => \%CustomerReference_of,
        'DocumentProducer' => \%DocumentProducer_of,
        'DocumentType' => \%DocumentType_of,
        'DocumentId' => \%DocumentId_of,
        'DocumentIdProducer' => \%DocumentIdProducer_of,
    },
    {
        'LineNumber' => 'SOAP::WSDL::XSD::Typelib::Builtin::nonNegativeInteger',
        'CustomerReference' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'DocumentProducer' => 'Shipment::FedEx::WSDL::RateTypes::UploadDocumentProducerType',
        'DocumentType' => 'Shipment::FedEx::WSDL::RateTypes::UploadDocumentType',
        'DocumentId' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'DocumentIdProducer' => 'Shipment::FedEx::WSDL::RateTypes::UploadDocumentIdProducer',
    },
    {

        'LineNumber' => 'LineNumber',
        'CustomerReference' => 'CustomerReference',
        'DocumentProducer' => 'DocumentProducer',
        'DocumentType' => 'DocumentType',
        'DocumentId' => 'DocumentId',
        'DocumentIdProducer' => 'DocumentIdProducer',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::FedEx::WSDL::RateTypes::UploadDocumentReferenceDetail

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
UploadDocumentReferenceDetail from the namespace http://fedex.com/ws/rate/v9.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * LineNumber (min/maxOccurs: 0/1)

=item * CustomerReference (min/maxOccurs: 0/1)

=item * DocumentProducer (min/maxOccurs: 0/1)

=item * DocumentType (min/maxOccurs: 0/1)

=item * DocumentId (min/maxOccurs: 0/1)

=item * DocumentIdProducer (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::FedEx::WSDL::RateTypes::UploadDocumentReferenceDetail

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::FedEx::WSDL::RateTypes::UploadDocumentReferenceDetail
   LineNumber =>  $some_value, # nonNegativeInteger
   CustomerReference =>  $some_value, # string
   DocumentProducer => $some_value, # UploadDocumentProducerType
   DocumentType => $some_value, # UploadDocumentType
   DocumentId =>  $some_value, # string
   DocumentIdProducer => $some_value, # UploadDocumentIdProducer
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
