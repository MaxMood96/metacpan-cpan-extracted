package Tomba::Leads;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Leads - Leads management for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Leads;

  my $tomba = Tomba::Leads->new("ta_xxxxx", "ts_xxxxx");
  my $leads = $tomba->ListLeads();

=head1 DESCRIPTION

Create, read, update, and delete leads.

=cut

#-------------------------------------------------------------------------------
# Leads Management
#-------------------------------------------------------------------------------

=head2 ListLeads

  my $data = $tomba->ListLeads();
  my $data = $tomba->ListLeads({ domain => "tomba.io", page => 1, limit => 10 });

Retrieve a paginated list of leads. Optionally filter by domain.

See L<https://docs.tomba.io/api/leads#retrieve-a-single-leads>

=cut

sub ListLeads {
    my ($self, $params) = @_;
    return $self->call(Tomba::Client::LEADS_PATH, $params);
}

=head2 GetLead

  my $data = $tomba->GetLead($lead_id);

Retrieve detailed information for a specific lead.

See L<https://docs.tomba.io/api/leads#retrieve-a-single-leads-leadid>

=cut

sub GetLead {
    my ($self, $lead_id) = @_;
    return $self->call(Tomba::Client::LEADS_PATH . "/$lead_id");
}

=head2 CreateLead

  my $data = $tomba->CreateLead({
      email      => "test@example.com",
      first_name => "John",
      last_name  => "Doe",
      company    => "Example Inc",
  });

Create a new lead. If the email already exists, fails with 422 status code.

See L<https://docs.tomba.io/api/leads#post-leads>

=cut

sub CreateLead {
    my ($self, $body) = @_;
    return $self->post(Tomba::Client::LEADS_PATH, $body);
}

=head2 UpdateLead

  my $data = $tomba->UpdateLead($lead_id, { first_name => "Jane" });

Update the fields of a lead using its ID.

See L<https://docs.tomba.io/api/leads#put-leads-leadid>

=cut

sub UpdateLead {
    my ($self, $lead_id, $body) = @_;
    return $self->put(Tomba::Client::LEADS_PATH . "/$lead_id", $body);
}

=head2 DeleteLead

  my $data = $tomba->DeleteLead($lead_id);

Delete a lead using its ID.

See L<https://docs.tomba.io/api/leads#delete-a-leads-leadid>

=cut

sub DeleteLead {
    my ($self, $lead_id) = @_;
    return $self->delete_request(Tomba::Client::LEADS_PATH . "/$lead_id");
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
