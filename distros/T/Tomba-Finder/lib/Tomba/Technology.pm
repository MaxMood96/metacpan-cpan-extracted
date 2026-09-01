package Tomba::Technology;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Technology - Technology detection for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Technology;

  my $tomba = Tomba::Technology->new("ta_xxxxx", "ts_xxxxx");
  my $tech = $tomba->Technology("tomba.io");

=head1 DESCRIPTION

Retrieve the technologies used by a specific domain.

=cut

#-------------------------------------------------------------------------------
# Technology
#-------------------------------------------------------------------------------

=head2 Technology

  my $data = $tomba->Technology("tomba.io");

Retrieve the technologies used by a specific domain.

See L<https://docs.tomba.io/api/domain#get-technology>

=cut

sub Technology {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::TECHNOLOGY_PATH, $params);
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
