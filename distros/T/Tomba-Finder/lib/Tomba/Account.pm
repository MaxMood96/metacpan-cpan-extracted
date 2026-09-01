package Tomba::Account;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Account - Account information for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Account;

  my $tomba = Tomba::Account->new("ta_xxxxx", "ts_xxxxx");
  my $account = $tomba->Account();

=head1 DESCRIPTION

Retrieve information about the current Tomba account.

=cut

#-------------------------------------------------------------------------------
# Account
#-------------------------------------------------------------------------------

=head2 Account

  my $data = $tomba->Account();

Returns information about the current account.

See L<https://docs.tomba.io/api/account#get-me>

=cut

sub Account {
    my ($self) = @_;
    return $self->call(Tomba::Client::ACCOUNT_PATH);
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
