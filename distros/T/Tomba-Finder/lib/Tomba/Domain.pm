package Tomba::Domain;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Domain - Domain search for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Domain;

  my $tomba = Tomba::Domain->new("ta_xxxxx", "ts_xxxxx");
  my $results = $tomba->DomainSearch("tomba.io");

=head1 DESCRIPTION

Search emails based on a website domain.

=cut

#-------------------------------------------------------------------------------
# Domain Search
#-------------------------------------------------------------------------------

=head2 DomainSearch

  my $data = $tomba->DomainSearch("tomba.io");
  print $data->{data}->{organization}->{description};

Search emails based on a website domain. Returns all email addresses found on the internet for the given domain.

See L<https://docs.tomba.io/api/finder#get-domain-search>

=cut

sub DomainSearch {
    my ($self, $domain, $opts) = @_;
    my $params = {
        domain => $domain,
    };
    if ($opts && ref($opts) eq 'HASH') {
        $params->{enrich_mobile} = $opts->{enrich_mobile} if exists $opts->{enrich_mobile};
        $params->{webhook_url}   = $opts->{webhook_url}   if exists $opts->{webhook_url};
    }
    return $self->call(Tomba::Client::SEARCH_PATH, $params);
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
