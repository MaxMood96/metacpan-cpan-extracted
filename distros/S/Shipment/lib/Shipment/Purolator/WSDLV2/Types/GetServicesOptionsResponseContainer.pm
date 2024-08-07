package Shipment::Purolator::WSDLV2::Types::GetServicesOptionsResponseContainer;
$Shipment::Purolator::WSDLV2::Types::GetServicesOptionsResponseContainer::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://purolator.com/pws/datatypes/v2' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}


use base qw(Shipment::Purolator::WSDLV2::Types::ResponseContainer);
# Variety: sequence
use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %ResponseInformation_of :ATTR(:get<ResponseInformation>);
my %Services_of :ATTR(:get<Services>);

__PACKAGE__->_factory(
    [ qw(        ResponseInformation
        Services

    ) ],
    {
        'ResponseInformation' => \%ResponseInformation_of,
        'Services' => \%Services_of,
    },
    {
        'ResponseInformation' => 'Shipment::Purolator::WSDLV2::Types::ResponseInformation',
        'Services' => 'Shipment::Purolator::WSDLV2::Types::ArrayOfService',
    },
    {

        'ResponseInformation' => 'ResponseInformation',
        'Services' => 'Services',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::Purolator::WSDLV2::Types::GetServicesOptionsResponseContainer

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
GetServicesOptionsResponseContainer from the namespace http://purolator.com/pws/datatypes/v2.

GetServicesOptionsResponse

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Services (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::Purolator::WSDLV2::Types::GetServicesOptionsResponseContainer

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::Purolator::WSDLV2::Types::GetServicesOptionsResponseContainer
   Services =>  { # Shipment::Purolator::WSDLV2::Types::ArrayOfService
     Service =>  { # Shipment::Purolator::WSDLV2::Types::Service
       ID =>  $some_value, # string
       Description =>  $some_value, # string
       PackageType =>  $some_value, # string
       PackageTypeDescription =>  $some_value, # string
       Options =>  { # Shipment::Purolator::WSDLV2::Types::ArrayOfOption
         Option =>  { # Shipment::Purolator::WSDLV2::Types::Option
           ID =>  $some_value, # string
           Description =>  $some_value, # string
           ValueType => $some_value, # ValueType
           AvailableForPieces =>  $some_value, # boolean
           PossibleValues =>  { # Shipment::Purolator::WSDLV2::Types::ArrayOfOptionValue
             OptionValue =>  { # Shipment::Purolator::WSDLV2::Types::OptionValue
               Value =>  $some_value, # string
               Description =>  $some_value, # string
             },
           },
         },
       },
     },
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
