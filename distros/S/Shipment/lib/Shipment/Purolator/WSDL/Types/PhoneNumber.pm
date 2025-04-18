package Shipment::Purolator::WSDL::Types::PhoneNumber;
$Shipment::Purolator::WSDL::Types::PhoneNumber::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://purolator.com/pws/datatypes/v1' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %CountryCode_of :ATTR(:get<CountryCode>);
my %AreaCode_of :ATTR(:get<AreaCode>);
my %Phone_of :ATTR(:get<Phone>);
my %Extension_of :ATTR(:get<Extension>);

__PACKAGE__->_factory(
    [ qw(        CountryCode
        AreaCode
        Phone
        Extension

    ) ],
    {
        'CountryCode' => \%CountryCode_of,
        'AreaCode' => \%AreaCode_of,
        'Phone' => \%Phone_of,
        'Extension' => \%Extension_of,
    },
    {
        'CountryCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'AreaCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'Phone' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'Extension' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
    },
    {

        'CountryCode' => 'CountryCode',
        'AreaCode' => 'AreaCode',
        'Phone' => 'Phone',
        'Extension' => 'Extension',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::Purolator::WSDL::Types::PhoneNumber

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
PhoneNumber from the namespace http://purolator.com/pws/datatypes/v1.

PhoneNumber

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * CountryCode (min/maxOccurs: 1/1)

=item * AreaCode (min/maxOccurs: 1/1)

=item * Phone (min/maxOccurs: 1/1)

=item * Extension (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::Purolator::WSDL::Types::PhoneNumber

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::Purolator::WSDL::Types::PhoneNumber
   CountryCode =>  $some_value, # string
   AreaCode =>  $some_value, # string
   Phone =>  $some_value, # string
   Extension =>  $some_value, # string
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
