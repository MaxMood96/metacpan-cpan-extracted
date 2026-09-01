package Tomba::LeadsList;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::LeadsList - Leads lists management for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::LeadsList;

  my $tomba = Tomba::LeadsList->new("ta_xxxxx", "ts_xxxxx");
  my $lists = $tomba->ListLeadsLists();

=head1 DESCRIPTION

Create, read, update, and delete leads lists.

=cut

#-------------------------------------------------------------------------------
# Leads Lists Management
#-------------------------------------------------------------------------------

=head2 ListLeadsLists

  my $data = $tomba->ListLeadsLists();

Retrieve a list of leads lists.

See L<https://docs.tomba.io/api/lead-lists#get-leads_lists>

=cut

sub ListLeadsLists {
    my ($self) = @_;
    return $self->call(Tomba::Client::LEADS_LISTS_PATH);
}

=head2 GetLeadsList

  my $data = $tomba->GetLeadsList($list_id);

Retrieve details of a specific leads list.

See L<https://docs.tomba.io/api/lead-lists#get-leads_lists-listid>

=cut

sub GetLeadsList {
    my ($self, $list_id) = @_;
    return $self->call(Tomba::Client::LEADS_LISTS_PATH . "/$list_id");
}

=head2 CreateLeadsList

  my $data = $tomba->CreateLeadsList({ name => "My List" });

Create a new leads list.

See L<https://docs.tomba.io/api/lead-lists#post-leads_lists>

=cut

sub CreateLeadsList {
    my ($self, $body) = @_;
    return $self->post(Tomba::Client::LEADS_LISTS_PATH, $body);
}

=head2 UpdateLeadsList

  my $data = $tomba->UpdateLeadsList($list_id, { name => "Updated List" });

Update a specific leads list.

See L<https://docs.tomba.io/api/lead-lists#put-leads_lists-listid>

=cut

sub UpdateLeadsList {
    my ($self, $list_id, $body) = @_;
    return $self->put(Tomba::Client::LEADS_LISTS_PATH . "/$list_id", $body);
}

=head2 DeleteLeadsList

  my $data = $tomba->DeleteLeadsList($list_id);

Delete a specific leads list.

See L<https://docs.tomba.io/api/lead-lists#delete-leads_lists-listid>

=cut

sub DeleteLeadsList {
    my ($self, $list_id) = @_;
    return $self->delete_request(Tomba::Client::LEADS_LISTS_PATH . "/$list_id");
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
