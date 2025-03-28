################################################################################
#  Copyright 2008 Amazon Technologies, Inc.
#  Licensed under the Apache License, Version 2.0 (the "License");
#
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at: http://aws.amazon.com/apache2.0
#  This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#  CONDITIONS OF ANY KIND, either express or implied. See the License for the
#  specific language governing permissions and limitations under the License.
################################################################################
#    __  _    _  ___
#   (  )( \/\/ )/ __)
#   /__\ \    / \__ \
#  (_)(_) \/\/  (___/
#
#  Amazon SQS Perl Library
#  API Version: 2009-02-01
#  Generated: Thu Apr 09 01:13:11 PDT 2009
#

package Amazon::SQS::Model::ReceiveMessageResponse;

use strict;
use warnings;

use Amazon::SQS::Constants qw(:chars);
use XML::Simple;

use parent qw (Amazon::SQS::Model);

#
# Amazon::SQS::Model::ReceiveMessageResponse
#
# Properties:
#
#
# ReceiveMessageResult: Amazon::SQS::Model::ReceiveMessageResult
# ResponseMetadata: Amazon::SQS::Model::ResponseMetadata
#
#
#
sub new {
  my ( $class, $data ) = @_;
  my $self = {};
  $self->{_fields} = {

    ReceiveMessageResult => { FieldValue => undef, FieldType => 'Amazon::SQS::Model::ReceiveMessageResult' },
    ResponseMetadata     => { FieldValue => undef, FieldType => 'Amazon::SQS::Model::ResponseMetadata' },
  };

  bless $self, $class;

  if ( defined $data ) {
    $self->_fromHashRef($data);
  }

  return $self;
}

#
# Construct Amazon::SQS::Model::ReceiveMessageResponse from XML string
#
sub fromXML {
  my ( $self, $xml ) = @_;
  my $tree = XML::Simple::XMLin($xml);

  # TODO: check valid XML (is this a response XML?)
  return Amazon::SQS::Model::ReceiveMessageResponse->new($tree);

}

sub getReceiveMessageResult {
  return shift->{_fields}->{ReceiveMessageResult}->{FieldValue};
}

sub setReceiveMessageResult {
  my ( $self, $value ) = @_;
  return $self->{_fields}->{ReceiveMessageResult}->{FieldValue} = $value;
}

sub withReceiveMessageResult {
  my ( $self, $value ) = @_;
  $self->setReceiveMessageResult($value);
  return $self;
}

sub isSetReceiveMessageResult {
  return defined( shift->{_fields}->{ReceiveMessageResult}->{FieldValue} );

}

sub getResponseMetadata {
  return shift->{_fields}->{ResponseMetadata}->{FieldValue};
}

sub setResponseMetadata {
  my ( $self, $value ) = @_;
  return $self->{_fields}->{ResponseMetadata}->{FieldValue} = $value;
}

sub withResponseMetadata {
  my ( $self, $value ) = @_;
  $self->setResponseMetadata($value);
  return $self;
}

sub isSetResponseMetadata {
  return defined( shift->{_fields}->{ResponseMetadata}->{FieldValue} );

}

#
# XML Representation for this object
#
# Returns string XML for this object
#
sub toXML {
  my ($self) = @_;

  my $xml = $EMPTY;

  $xml .= q{<ReceiveMessageResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">};
  $xml .= $self->_toXMLFragment();
  $xml .= '</ReceiveMessageResponse>';

  return $xml;
}

1;
