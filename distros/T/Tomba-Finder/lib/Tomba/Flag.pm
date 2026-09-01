package Tomba::Flag;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Flag - Data flags for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Flag;

  my $tomba = Tomba::Flag->new("ta_xxxxx", "ts_xxxxx");
  my $flags = $tomba->ListFlags();

=head1 DESCRIPTION

Report incorrect data such as hard bounces, invalid emails, or wrong organization info.

=cut

#-------------------------------------------------------------------------------
# Flags
#-------------------------------------------------------------------------------

=head2 ListFlags

  my $data = $tomba->ListFlags();
  my $data = $tomba->ListFlags({ page => 1, limit => 10 });

Returns a paginated list of data flags submitted by the authenticated user.

See L<https://docs.tomba.io/api/flag#get-flag>

=cut

sub ListFlags {
    my ($self, $params) = @_;
    return $self->call(Tomba::Client::FLAG_PATH, $params);
}

=head2 CreateFlag

  my $data = $tomba->CreateFlag({
      flag_type => "email",
      value     => "bounced@example.com",
      reason    => "hard_bounce",
      comment   => "Email hard bounced",
  });

Report incorrect data such as hard bounces, invalid emails, or wrong organization info.

See L<https://docs.tomba.io/api/flag#post-flag>

=cut

sub CreateFlag {
    my ($self, $body) = @_;
    return $self->post(Tomba::Client::FLAG_PATH, $body);
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
