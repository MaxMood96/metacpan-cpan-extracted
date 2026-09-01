package Tomba::Location;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Location - Employee location breakdown for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Location;

  my $tomba = Tomba::Location->new("ta_xxxxx", "ts_xxxxx");
  my $location = $tomba->GetLocation("tomba.io");

=head1 DESCRIPTION

Retrieve employees location breakdown based on the domain name.

=cut

#-------------------------------------------------------------------------------
# Location
#-------------------------------------------------------------------------------

=head2 GetLocation

  my $data = $tomba->GetLocation("tomba.io");

Retrieve employees location breakdown based on the domain name.

See L<https://docs.tomba.io/api/finder#get-location>

=cut

sub GetLocation {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::LOCATION_PATH, $params);
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
