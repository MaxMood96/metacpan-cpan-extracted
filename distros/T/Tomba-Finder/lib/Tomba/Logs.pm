package Tomba::Logs;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Logs - Request logs for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Logs;

  my $tomba = Tomba::Logs->new("ta_xxxxx", "ts_xxxxx");
  my $logs = $tomba->Logs();

=head1 DESCRIPTION

Returns your last 1,000 requests made during the last 3 months.

=cut

#-------------------------------------------------------------------------------
# Logs
#-------------------------------------------------------------------------------

=head2 Logs

  my $data = $tomba->Logs();

Returns your last 1,000 requests made during the last 3 months.

See L<https://docs.tomba.io/api/account#get-logs>

=cut

sub Logs {
    my ($self, $params) = @_;
    return $self->call(Tomba::Client::LOGS_PATH, $params);
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
