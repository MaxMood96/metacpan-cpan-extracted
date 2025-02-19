package Shipment::FedEx::WSDL::RateTypes::CustomLabelPosition;
$Shipment::FedEx::WSDL::RateTypes::CustomLabelPosition::VERSION = '3.10';
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

my %X_of :ATTR(:get<X>);
my %Y_of :ATTR(:get<Y>);

__PACKAGE__->_factory(
    [ qw(        X
        Y

    ) ],
    {
        'X' => \%X_of,
        'Y' => \%Y_of,
    },
    {
        'X' => 'SOAP::WSDL::XSD::Typelib::Builtin::nonNegativeInteger',
        'Y' => 'SOAP::WSDL::XSD::Typelib::Builtin::nonNegativeInteger',
    },
    {

        'X' => 'X',
        'Y' => 'Y',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::FedEx::WSDL::RateTypes::CustomLabelPosition

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
CustomLabelPosition from the namespace http://fedex.com/ws/rate/v9.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * X (min/maxOccurs: 0/1)

=item * Y (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::FedEx::WSDL::RateTypes::CustomLabelPosition

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::FedEx::WSDL::RateTypes::CustomLabelPosition
   X =>  $some_value, # nonNegativeInteger
   Y =>  $some_value, # nonNegativeInteger
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
