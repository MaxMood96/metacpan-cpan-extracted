package Tomba::Keys;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Keys - API keys management for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Keys;

  my $tomba = Tomba::Keys->new("ta_xxxxx", "ts_xxxxx");
  my $keys = $tomba->ListKeys();

=head1 DESCRIPTION

Manage API keys for the Tomba account.

=cut

#-------------------------------------------------------------------------------
# API Keys Management
#-------------------------------------------------------------------------------

=head2 ListKeys

  my $data = $tomba->ListKeys();

Retrieve a list of API keys.

See L<https://docs.tomba.io/api/keys#get-keys>

=cut

sub ListKeys {
    my ($self) = @_;
    return $self->call(Tomba::Client::KEYS_PATH);
}

=head2 GetKey

  my $data = $tomba->GetKey($key_id);

Retrieve details for a specific API key.

See L<https://docs.tomba.io/api/keys#get-keys-keyid>

=cut

sub GetKey {
    my ($self, $key_id) = @_;
    return $self->call(Tomba::Client::KEYS_PATH . "/$key_id");
}

=head2 CreateKey

  my $data = $tomba->CreateKey();

Create a new API key. The Free plan can create only one key.

See L<https://docs.tomba.io/api/keys#post-keys>

=cut

sub CreateKey {
    my ($self) = @_;
    return $self->post(Tomba::Client::KEYS_PATH, {});
}

=head2 ResetKey

  my $data = $tomba->ResetKey($key_id);

Reset (regenerate) a specific API key.

See L<https://docs.tomba.io/api/keys#put-keys-keyid>

=cut

sub ResetKey {
    my ($self, $key_id) = @_;
    return $self->put(Tomba::Client::KEYS_PATH . "/$key_id", {});
}

=head2 DeleteKey

  my $data = $tomba->DeleteKey($key_id);

Delete a specific API key.

See L<https://docs.tomba.io/api/keys#delete-an-api-keys-keyid>

=cut

sub DeleteKey {
    my ($self, $key_id) = @_;
    return $self->delete_request(Tomba::Client::KEYS_PATH . "/$key_id");
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
