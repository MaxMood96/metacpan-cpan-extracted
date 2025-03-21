package Shipment::Purolator::WSDLV2::Types::ValidationFault;
$Shipment::Purolator::WSDLV2::Types::ValidationFault::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://www.microsoft.com/practices/EnterpriseLibrary/2007/01/wcf/validation' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %Details_of :ATTR(:get<Details>);

__PACKAGE__->_factory(
    [ qw(        Details

    ) ],
    {
        'Details' => \%Details_of,
    },
    {
        'Details' => 'Shipment::Purolator::WSDLV2::Types::ArrayOfValidationDetail',
    },
    {

        'Details' => 'Details',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::Purolator::WSDLV2::Types::ValidationFault

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
ValidationFault from the namespace http://www.microsoft.com/practices/EnterpriseLibrary/2007/01/wcf/validation.

This class is used to return information to a WCF client when validation fails on a service parameter.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Details (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::Purolator::WSDLV2::Types::ValidationFault

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::Purolator::WSDLV2::Types::ValidationFault
   Details =>  { # Shipment::Purolator::WSDLV2::Types::ArrayOfValidationDetail
     ValidationDetail =>  { # Shipment::Purolator::WSDLV2::Types::ValidationDetail
       Key =>  $some_value, # string
       Message =>  $some_value, # string
       Tag =>  $some_value, # string
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
