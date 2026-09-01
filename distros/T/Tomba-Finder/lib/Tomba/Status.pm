package Tomba::Status;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Status - Domain status and autocomplete for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Status;

  my $tomba = Tomba::Status->new("ta_xxxxx", "ts_xxxxx");
  my $status = $tomba->Status("gmail.com");
  my $suggestions = $tomba->Autocomplete("googl");

=head1 DESCRIPTION

Check domain status (webmail/disposable) and auto-complete company names.

=cut

#-------------------------------------------------------------------------------
# Domain Status
#-------------------------------------------------------------------------------

=head2 Status

  my $data = $tomba->Status("gmail.com");

Returns domain status indicating if it is a webmail or disposable domain.

See L<https://docs.tomba.io/api/domain#get-domain-status>

=cut

sub Status {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::STATUS_PATH, $params);
}

#-------------------------------------------------------------------------------
# Domain Suggestions (Autocomplete)
#-------------------------------------------------------------------------------

=head2 Autocomplete

  my $data = $tomba->Autocomplete("googl");

Company Autocomplete API that lets you auto-complete company names and retrieve logo and domain information.

See L<https://docs.tomba.io/api/domain-suggestions#get-domain-suggestions>

=cut

sub Autocomplete {
    my ($self, $search) = @_;
    my $params = {
        query => $search,
    };
    return $self->call(Tomba::Client::AUTOCOMPLETE_PATH, $params);
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
