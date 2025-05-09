
package Shipment::Purolator::WSDLV2::Elements::Dimension;
$Shipment::Purolator::WSDLV2::Elements::Dimension::VERSION = '3.10';
use strict;
use warnings;

{ # BLOCK to scope variables

sub get_xmlns { 'http://purolator.com/pws/datatypes/v2' }

__PACKAGE__->__set_name('Dimension');
__PACKAGE__->__set_nillable(1);
__PACKAGE__->__set_minOccurs();
__PACKAGE__->__set_maxOccurs();
__PACKAGE__->__set_ref();
use base qw(
    SOAP::WSDL::XSD::Typelib::Element
    Shipment::Purolator::WSDLV2::Types::Dimension
);

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::Purolator::WSDLV2::Elements::Dimension

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined element
Dimension from the namespace http://purolator.com/pws/datatypes/v2.

=head1 NAME

Shipment::Purolator::WSDLV2::Elements::Dimension

=head1 METHODS

=head2 new

 my $element = Shipment::Purolator::WSDLV2::Elements::Dimension->new($data);

Constructor. The following data structure may be passed to new():

 { # Shipment::Purolator::WSDLV2::Types::Dimension
   Value =>  $some_value, # decimal
   DimensionUnit => $some_value, # DimensionUnit
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
