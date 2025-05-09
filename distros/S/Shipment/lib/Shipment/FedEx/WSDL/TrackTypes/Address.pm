package Shipment::FedEx::WSDL::TrackTypes::Address;
$Shipment::FedEx::WSDL::TrackTypes::Address::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://fedex.com/ws/track/v9' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %StreetLines_of :ATTR(:get<StreetLines>);
my %City_of :ATTR(:get<City>);
my %StateOrProvinceCode_of :ATTR(:get<StateOrProvinceCode>);
my %PostalCode_of :ATTR(:get<PostalCode>);
my %UrbanizationCode_of :ATTR(:get<UrbanizationCode>);
my %CountryCode_of :ATTR(:get<CountryCode>);
my %CountryName_of :ATTR(:get<CountryName>);
my %Residential_of :ATTR(:get<Residential>);

__PACKAGE__->_factory(
    [ qw(        StreetLines
        City
        StateOrProvinceCode
        PostalCode
        UrbanizationCode
        CountryCode
        CountryName
        Residential

    ) ],
    {
        'StreetLines' => \%StreetLines_of,
        'City' => \%City_of,
        'StateOrProvinceCode' => \%StateOrProvinceCode_of,
        'PostalCode' => \%PostalCode_of,
        'UrbanizationCode' => \%UrbanizationCode_of,
        'CountryCode' => \%CountryCode_of,
        'CountryName' => \%CountryName_of,
        'Residential' => \%Residential_of,
    },
    {
        'StreetLines' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'City' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'StateOrProvinceCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'PostalCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'UrbanizationCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'CountryCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'CountryName' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'Residential' => 'SOAP::WSDL::XSD::Typelib::Builtin::boolean',
    },
    {

        'StreetLines' => 'StreetLines',
        'City' => 'City',
        'StateOrProvinceCode' => 'StateOrProvinceCode',
        'PostalCode' => 'PostalCode',
        'UrbanizationCode' => 'UrbanizationCode',
        'CountryCode' => 'CountryCode',
        'CountryName' => 'CountryName',
        'Residential' => 'Residential',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::FedEx::WSDL::TrackTypes::Address

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
Address from the namespace http://fedex.com/ws/track/v9.

Descriptive data for a physical location. May be used as an actual physical address (place to which one could go), or as a container of "address parts" which should be handled as a unit (such as a city-state-ZIP combination within the US).

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * StreetLines

=item * City

=item * StateOrProvinceCode

=item * PostalCode

=item * UrbanizationCode

=item * CountryCode

=item * CountryName

=item * Residential

=back

=head1 NAME

Shipment::FedEx::WSDL::TrackTypes::Address

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::FedEx::WSDL::TrackTypes::Address
   StreetLines =>  $some_value, # string
   City =>  $some_value, # string
   StateOrProvinceCode =>  $some_value, # string
   PostalCode =>  $some_value, # string
   UrbanizationCode =>  $some_value, # string
   CountryCode =>  $some_value, # string
   CountryName =>  $some_value, # string
   Residential =>  $some_value, # boolean
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
