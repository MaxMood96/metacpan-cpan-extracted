package Tomba::Phone;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Phone - Phone finder and validator for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Phone;

  my $tomba = Tomba::Phone->new("ta_xxxxx", "ts_xxxxx");
  my $phone = $tomba->PhoneFinder({ email => 'm@wordpress.org' });
  my $valid = $tomba->PhoneValidator("+14155552671", "US");

=head1 DESCRIPTION

Find and validate phone numbers via the Tomba API.

=cut

#-------------------------------------------------------------------------------
# Phone Finder
#-------------------------------------------------------------------------------

=head2 PhoneFinder

  my $data = $tomba->PhoneFinder({ email => 'm@wordpress.org' });
  my $data = $tomba->PhoneFinder({ domain => 'tomba.io' });
  my $data = $tomba->PhoneFinder({ linkedin => 'https://www.linkedin.com/in/alex-maccaw-ab592978' });

Search for phone numbers based on an email, domain, or LinkedIn URL.

See L<https://docs.tomba.io/api/phone#get-phone-finder>

=cut

sub PhoneFinder {
    my ($self, $params) = @_;
    return $self->call(Tomba::Client::PHONE_FINDER_PATH, $params);
}

#-------------------------------------------------------------------------------
# Phone Validator
#-------------------------------------------------------------------------------

=head2 PhoneValidator

  my $data = $tomba->PhoneValidator("+14155552671", "US");

Validate a phone number and retrieve its associated information.

See L<https://docs.tomba.io/api/phone#get-phone-validator>

=cut

sub PhoneValidator {
    my ($self, $phone, $country_code) = @_;
    my $params = {
        phone => $phone,
    };
    $params->{country_code} = $country_code if $country_code;
    return $self->call(Tomba::Client::PHONE_VALIDATOR_PATH, $params);
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
