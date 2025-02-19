package Shipment::Purolator::WSDLV2::Types::Piece;
$Shipment::Purolator::WSDLV2::Types::Piece::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://purolator.com/pws/datatypes/v2' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %Weight_of :ATTR(:get<Weight>);
my %Length_of :ATTR(:get<Length>);
my %Width_of :ATTR(:get<Width>);
my %Height_of :ATTR(:get<Height>);
my %Options_of :ATTR(:get<Options>);

__PACKAGE__->_factory(
    [ qw(        Weight
        Length
        Width
        Height
        Options

    ) ],
    {
        'Weight' => \%Weight_of,
        'Length' => \%Length_of,
        'Width' => \%Width_of,
        'Height' => \%Height_of,
        'Options' => \%Options_of,
    },
    {
        'Weight' => 'Shipment::Purolator::WSDLV2::Types::Weight',
        'Length' => 'Shipment::Purolator::WSDLV2::Types::Dimension',
        'Width' => 'Shipment::Purolator::WSDLV2::Types::Dimension',
        'Height' => 'Shipment::Purolator::WSDLV2::Types::Dimension',
        'Options' => 'Shipment::Purolator::WSDLV2::Types::ArrayOfOptionIDValuePair',
    },
    {

        'Weight' => 'Weight',
        'Length' => 'Length',
        'Width' => 'Width',
        'Height' => 'Height',
        'Options' => 'Options',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::Purolator::WSDLV2::Types::Piece

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
Piece from the namespace http://purolator.com/pws/datatypes/v2.

Piece

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Weight (min/maxOccurs: 1/1)

=item * Length (min/maxOccurs: 0/1)

=item * Width (min/maxOccurs: 0/1)

=item * Height (min/maxOccurs: 0/1)

=item * Options (min/maxOccurs: 0/1)

=back

=head1 NAME

Shipment::Purolator::WSDLV2::Types::Piece

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::Purolator::WSDLV2::Types::Piece
   Weight =>  { # Shipment::Purolator::WSDLV2::Types::Weight
     Value =>  $some_value, # decimal
     WeightUnit => $some_value, # WeightUnit
   },
   Length =>  { # Shipment::Purolator::WSDLV2::Types::Dimension
     Value =>  $some_value, # decimal
     DimensionUnit => $some_value, # DimensionUnit
   },
   Width => {}, # Shipment::Purolator::WSDLV2::Types::Dimension
   Height => {}, # Shipment::Purolator::WSDLV2::Types::Dimension
   Options =>  { # Shipment::Purolator::WSDLV2::Types::ArrayOfOptionIDValuePair
     OptionIDValuePair =>  { # Shipment::Purolator::WSDLV2::Types::OptionIDValuePair
       ID =>  $some_value, # string
       Value =>  $some_value, # string
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
