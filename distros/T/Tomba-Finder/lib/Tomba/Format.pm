package Tomba::Format;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Format - Email format patterns for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Format;

  my $tomba = Tomba::Format->new("ta_xxxxx", "ts_xxxxx");
  my $format = $tomba->EmailFormat("tomba.io");

=head1 DESCRIPTION

Retrieve the email format patterns used by a specific domain.

=cut

#-------------------------------------------------------------------------------
# Email Format
#-------------------------------------------------------------------------------

=head2 EmailFormat

  my $data = $tomba->EmailFormat("tomba.io");

Retrieve the email format patterns used by a specific domain.

See L<https://docs.tomba.io/api/finder#get-email-format>

=cut

sub EmailFormat {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::EMAIL_FORMAT_PATH, $params);
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
