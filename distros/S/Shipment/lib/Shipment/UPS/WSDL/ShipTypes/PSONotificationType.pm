package Shipment::UPS::WSDL::ShipTypes::PSONotificationType;
$Shipment::UPS::WSDL::ShipTypes::PSONotificationType::VERSION = '3.10';
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://www.ups.com/XMLSchema/XOLTWS/Ship/v1.0' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %NotificationCode_of :ATTR(:get<NotificationCode>);
my %EMail_of :ATTR(:get<EMail>);

__PACKAGE__->_factory(
    [ qw(        NotificationCode
        EMail

    ) ],
    {
        'NotificationCode' => \%NotificationCode_of,
        'EMail' => \%EMail_of,
    },
    {
        'NotificationCode' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
        'EMail' => 'Shipment::UPS::WSDL::ShipTypes::EmailDetailsType',
    },
    {

        'NotificationCode' => 'NotificationCode',
        'EMail' => 'EMail',
    }
);

} # end BLOCK







1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Shipment::UPS::WSDL::ShipTypes::PSONotificationType

=head1 VERSION

version 3.10

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
PSONotificationType from the namespace http://www.ups.com/XMLSchema/XOLTWS/Ship/v1.0.

=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * NotificationCode (min/maxOccurs: 1/1)

=item * EMail (min/maxOccurs: 1/1)

=back

=head1 NAME

Shipment::UPS::WSDL::ShipTypes::PSONotificationType

=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # Shipment::UPS::WSDL::ShipTypes::PSONotificationType
   NotificationCode =>  $some_value, # string
   EMail =>  { # Shipment::UPS::WSDL::ShipTypes::EmailDetailsType
     EMailAddress =>  $some_value, # string
     UndeliverableEMailAddress =>  $some_value, # string
     FromEMailAddress =>  $some_value, # string
     FromName =>  $some_value, # string
     Memo =>  $some_value, # string
     Subject =>  $some_value, # string
     SubjectCode =>  $some_value, # string
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
