package Tomba::Similar;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Similar - Similar domains for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Similar;

  my $tomba = Tomba::Similar->new("ta_xxxxx", "ts_xxxxx");
  my $similar = $tomba->Similar("tomba.io");

=head1 DESCRIPTION

Retrieve similar domains based on a specific domain.

=cut

#-------------------------------------------------------------------------------
# Similar
#-------------------------------------------------------------------------------

=head2 Similar

  my $data = $tomba->Similar("tomba.io");

Retrieve similar domains based on a specific domain.

See L<https://docs.tomba.io/api/domain#get-similar>

=cut

sub Similar {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::SIMILAR_PATH, $params);
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
