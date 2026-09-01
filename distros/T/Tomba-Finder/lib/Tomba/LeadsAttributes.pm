package Tomba::LeadsAttributes;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::LeadsAttributes - Lead attributes management for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::LeadsAttributes;

  my $tomba = Tomba::LeadsAttributes->new("ta_xxxxx", "ts_xxxxx");
  my $attrs = $tomba->ListAttributes();

=head1 DESCRIPTION

Create, read, update, and delete lead attributes.

=cut

#-------------------------------------------------------------------------------
# Lead Attributes Management
#-------------------------------------------------------------------------------

=head2 ListAttributes

  my $data = $tomba->ListAttributes();

Retrieve a list of lead attributes.

See L<https://docs.tomba.io/api/lead-attributes#get-attributes>

=cut

sub ListAttributes {
    my ($self) = @_;
    return $self->call(Tomba::Client::ATTRIBUTES_PATH);
}

=head2 GetAttribute

  my $data = $tomba->GetAttribute($attribute_id);

Retrieve details for a specific lead attribute.

See L<https://docs.tomba.io/api/lead-attributes#get-attributes-attributeid>

=cut

sub GetAttribute {
    my ($self, $attribute_id) = @_;
    return $self->call(Tomba::Client::ATTRIBUTES_PATH . "/$attribute_id");
}

=head2 CreateAttribute

  my $data = $tomba->CreateAttribute({ name => "priority", type => "string" });

Create a new lead attribute.

See L<https://docs.tomba.io/api/lead-attributes#post-attributes>

=cut

sub CreateAttribute {
    my ($self, $body) = @_;
    return $self->post(Tomba::Client::ATTRIBUTES_PATH, $body);
}

=head2 UpdateAttribute

  my $data = $tomba->UpdateAttribute($attribute_id, { name => "priority", type => "number" });

Update a lead attribute.

See L<https://docs.tomba.io/api/lead-attributes#put-attributes-attributeid>

=cut

sub UpdateAttribute {
    my ($self, $attribute_id, $body) = @_;
    return $self->put(Tomba::Client::ATTRIBUTES_PATH . "/$attribute_id", $body);
}

=head2 DeleteAttribute

  my $data = $tomba->DeleteAttribute($attribute_id);

Delete a specific lead attribute.

See L<https://docs.tomba.io/api/lead-attributes#delete-attributes-attributeid>

=cut

sub DeleteAttribute {
    my ($self, $attribute_id) = @_;
    return $self->delete_request(Tomba::Client::ATTRIBUTES_PATH . "/$attribute_id");
}

1;
__END__

=head1 AUTHOR

Mohamed Ben rebia, E<lt>b.mohamed@tomba.ioE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2023 Mohamed Benrebia <b.mohamed@tomba.io>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

L<http://www.apache.org/licenses/LICENSE-2.0>
