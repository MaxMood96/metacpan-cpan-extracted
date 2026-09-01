package Tomba::Verifier;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Verifier - Email verification for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Verifier;

  my $tomba = Tomba::Verifier->new("ta_xxxxx", "ts_xxxxx");
  my $verified = $tomba->EmailVerifier("b.mohamed@tomba.io");

=head1 DESCRIPTION

Verify the deliverability of an email address.

=cut

#-------------------------------------------------------------------------------
# Email Verifier
#-------------------------------------------------------------------------------

=head2 EmailVerifier

  my $data = $tomba->EmailVerifier("b.mohamed@tomba.io");

Verify the deliverability of an email address.

See L<https://docs.tomba.io/api/verifier#get-email-verifier>

=cut

sub EmailVerifier {
    my ($self, $email, $opts) = @_;
    my $params = {
        email => $email,
    };
    if ($opts && ref($opts) eq 'HASH') {
        $params->{webhook_url} = $opts->{webhook_url} if exists $opts->{webhook_url};
    }
    return $self->call(Tomba::Client::VERIFIER_PATH, $params);
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
