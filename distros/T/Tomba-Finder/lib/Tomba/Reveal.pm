package Tomba::Reveal;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Reveal - Companies search (Reveal) for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Reveal;

  my $tomba = Tomba::Reveal->new("ta_xxxxx", "ts_xxxxx");
  my $companies = $tomba->CompaniesSearch({ query => "Real Estate Agency in Europe", page => 1 });

=head1 DESCRIPTION

Search for companies using natural language queries or structured filters.

=cut

#-------------------------------------------------------------------------------
# Companies Search (Reveal)
#-------------------------------------------------------------------------------

=head2 CompaniesSearch

  my $data = $tomba->CompaniesSearch({ query => "Real Estate Agency in Europe", page => 1 });
  my $data = $tomba->CompaniesSearch({
      filters => {
          industry => { include => ["technology"] },
          location_country => { include => ["US"] },
      },
      page => 1,
  });

Search for companies using natural language queries or structured filters.

See L<https://docs.tomba.io/api/reveal#post-reveal-search>

=cut

sub CompaniesSearch {
    my ($self, $body) = @_;
    return $self->post(Tomba::Client::COMPANIES_SEARCH_PATH, $body);
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
