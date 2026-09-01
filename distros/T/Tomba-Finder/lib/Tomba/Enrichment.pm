package Tomba::Enrichment;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Enrichment - Clearbit-compatible enrichment APIs for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Enrichment;

  my $tomba = Tomba::Enrichment->new("ta_xxxxx", "ts_xxxxx");
  my $person   = $tomba->PersonFind("m@wordpress.org");
  my $company  = $tomba->CompanyFind("tomba.io");
  my $combined = $tomba->CombinedFind("m@wordpress.org");

=head1 DESCRIPTION

Clearbit-compatible Person, Company, and Combined enrichment APIs.

=cut

#-------------------------------------------------------------------------------
# Person Find (Clearbit-compatible)
#-------------------------------------------------------------------------------

=head2 PersonFind

  my $data = $tomba->PersonFind("m@wordpress.org");

Fetch social details tied to an email address (Clearbit-compatible Person API).

See L<https://docs.tomba.io/api/enrichment#get-people-find>

=cut

sub PersonFind {
    my ($self, $email) = @_;
    my $params = {
        email => $email,
    };
    return $self->call(Tomba::Client::PERSON_FIND_PATH, $params);
}

#-------------------------------------------------------------------------------
# Company Find (Clearbit-compatible)
#-------------------------------------------------------------------------------

=head2 CompanyFind

  my $data = $tomba->CompanyFind("tomba.io");

Look up company data via a domain (Clearbit-compatible Company API).

See L<https://docs.tomba.io/api/enrichment#get-companies-find>

=cut

sub CompanyFind {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::COMPANY_FIND_PATH, $params);
}

#-------------------------------------------------------------------------------
# Combined Find (Clearbit-compatible)
#-------------------------------------------------------------------------------

=head2 CombinedFind

  my $data = $tomba->CombinedFind("m@wordpress.org");

Returns both person and company data from an email (Clearbit-compatible Combined API).

See L<https://docs.tomba.io/api/enrichment#get-combined-find>

=cut

sub CombinedFind {
    my ($self, $email) = @_;
    my $params = {
        email => $email,
    };
    return $self->call(Tomba::Client::COMBINED_FIND_PATH, $params);
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
