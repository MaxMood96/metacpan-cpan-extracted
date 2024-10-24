package Shipment::FedEx::WSDL::ShipTypes::DeleteTagRequest;
$Shipment::FedEx::WSDL::ShipTypes::DeleteTagRequest::VERSION = '3.10';
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

my %WebAuthenticationDetail_of :ATTR(:get<WebAuthenticationDetail>);
my %ClientDetail_of :ATTR(:get<ClientDetail>);
my %TransactionDetail_of :ATTR(:get<TransactionDetail>);
my %Version_of :ATTR(:get<Version>);
my %DispatchLocationId_of :ATTR(:get<DispatchLocationId>);
my %DispatchDate_of :ATTR(:get<DispatchDate>);
my %Payment_of :ATTR(:get<Payment>);
my %ConfirmationNumber_of :ATTR(:get<ConfirmationNumber>);

__PACKAGE__->_factory(
    [ qw(        WebAuthenticationDetail
        ClientDetail
        TransactionDetail
        Version
        DispatchLocationId
        DispatchDate
        Payment
        ConfirmationNumber

    ) ],
    {
        'WebAuthenticationDetail' => \%WebAuthenticationDetail_of,
        'ClientDetail' => \%ClientDetail_of,
        'TransactionDetail' => \%TransactionDetail_of,
        'Version' => \%Version_of,
        'DispatchLocationId' => \%DispatchLocationId_of,
        'DispatchDate' => \%DispatchDate_of,
        'Payment' => \%Payment_of,
        'ConfirmationNumber' => \%ConfirmationNumber_of,
    },
    {
        'WebAuthenticationDetail' => 'Shipment::FedEx::WSDL::ShipTypes::WebAuthenticationDetail',
        'ClientDetail' => 'Shipment::FedEx::WSDL::ShipTypes::ClientDetail',
        'TransactionDetail' => 'Shipment::FedEx::WSDL::ShipTypes::TransactionDetail',
        'Version' => 'Shipment::FedEx::WSDL::ShipTypes::VersionId',
        'DispatchLocationId' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'DispatchDate' => 'SOAP::WSDL::XSD::Typelib::Builtin::date',
        'Payment' => 'Shipment::FedEx::WSDL::ShipTypes::Payment',
        'ConfirmationNumber' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
    },
    {

        'WebAuthenticationDetail' => 'WebAuthenticationDetail',
        'ClientDetail' => 'ClientDetail',
        'TransactionDetail' => 'TransactionDetail',
        'Version' => 'Version',
        'DispatchLocationId' => 'DispatchLocationId',
        'DispatchDate' => 'DispatchDate',
        'Payment' => 'Payment',
        'ConfirmationNumber' => 'ConfirmationNumber',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::FedEx::WSDL::ShipTypes::DeleteTagRequest

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
DeleteTagRequest from the namespace http://fedex.com/ws/ship/v9.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * WebAuthenticationDetail (min/maxOccurs: 1/1)

=item * ClientDetail (min/maxOccurs: 1/1)

=item * TransactionDetail (min/maxOccurs: 0/1)

=item * Version (min/maxOccurs: 1/1)

=item * DispatchLocationId (min/maxOccurs: 0/1)

=item * DispatchDate (min/maxOccurs: 0/1)

=item * Payment (min/maxOccurs: 1/1)

=item * ConfirmationNumber (min/maxOccurs: 1/1)

=back

=head1 NAME

Shipment::FedEx::WSDL::ShipTypes::DeleteTagRequest

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::FedEx::WSDL::ShipTypes::DeleteTagRequest
   WebAuthenticationDetail =>  { # Shipment::FedEx::WSDL::ShipTypes::WebAuthenticationDetail
     UserCredential =>  { # Shipment::FedEx::WSDL::ShipTypes::WebAuthenticationCredential
       Key =>  $some_value, # string
       Password =>  $some_value, # string
     },
   },
   ClientDetail =>  { # Shipment::FedEx::WSDL::ShipTypes::ClientDetail
     AccountNumber =>  $some_value, # string
     MeterNumber =>  $some_value, # string
     IntegratorId =>  $some_value, # string
     Localization =>  { # Shipment::FedEx::WSDL::ShipTypes::Localization
       LanguageCode =>  $some_value, # string
       LocaleCode =>  $some_value, # string
     },
   },
   TransactionDetail =>  { # Shipment::FedEx::WSDL::ShipTypes::TransactionDetail
     CustomerTransactionId =>  $some_value, # string
     Localization => {}, # Shipment::FedEx::WSDL::ShipTypes::Localization
   },
   Version =>  { # Shipment::FedEx::WSDL::ShipTypes::VersionId
     ServiceId =>  $some_value, # string
     Major =>  $some_value, # int
     Intermediate =>  $some_value, # int
     Minor =>  $some_value, # int
   },
   DispatchLocationId =>  $some_value, # string
   DispatchDate =>  $some_value, # date
   Payment =>  { # Shipment::FedEx::WSDL::ShipTypes::Payment
     PaymentType => $some_value, # PaymentType
     Payor =>  { # Shipment::FedEx::WSDL::ShipTypes::Payor
       AccountNumber =>  $some_value, # string
       CountryCode =>  $some_value, # string
     },
   },
   ConfirmationNumber =>  $some_value, # string
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
