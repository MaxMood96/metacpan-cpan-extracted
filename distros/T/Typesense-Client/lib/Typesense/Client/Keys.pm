package Typesense::Client::Keys;
$Typesense::Client::Keys::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

use Digest::SHA qw(hmac_sha256_base64);
use MIME::Base64 qw(encode_base64);
use Mojo::JSON qw(encode_json);

class Typesense::Client::Keys {
    field $client :param;

    method list { $client->request(GET => '/keys') }

    method get ($id) { $client->request(GET => "/keys/$id") }

    ## CAREFUL: the key in the clear comes back ONLY in this response. After
    ## that Typesense stores a hash and there is no way to recover it.
    method create ($body) { $client->request(POST => '/keys', json => $body) }

    method delete ($id) { $client->request(DELETE => "/keys/$id", ok_404 => 1) }

    ## Scoped key: derived locally, with no call to the server, by signing the
    ## embedded parameters with a search-only key. Use it to hand a browser a
    ## key that can only see its own data (per-customer filter_by, expiry)
    ## without exposing the parent key.
    method scoped ($search_key, $params) {
        my $payload = encode_json($params);
        my $digest  = hmac_sha256_base64($payload, $search_key);
        ## hmac_sha256_base64 does not pad; Typesense expects canonical base64.
        $digest .= '=' x ((4 - length($digest) % 4) % 4);
        my $prefix  = substr($search_key, 0, 4);
        return encode_base64($digest . $prefix . $payload, '');
    }
}

1;

__END__

=head1 NAME

Typesense::Client::Keys - API keys, including scoped search keys

=head1 SYNOPSIS

    # A key that can only search, only this collection.
    my $k = $ts->keys->create({
        description => 'storefront search',
        actions     => ['documents:search'],
        collections => ['products'],
    });
    my $search_key = $k->{value};    # the only time you will ever see it

    # Derive a per-customer key locally - no request to the server.
    my $scoped = $ts->keys->scoped($search_key, {
        filter_by => "customer_id:=$id",
        expires_at => time + 3600,
    });

=head1 DESCRIPTION

Two different things live here.

B<Real keys> are created on the server with a set of allowed actions and
collections. The plaintext value is returned B<only in the create response> -
afterwards Typesense stores a hash and it cannot be recovered. If you lose it,
you make a new key.

B<Scoped keys> are derived locally by signing a set of embedded search
parameters with a search-only key. They never touch the server. This is how you
hand a browser a key that can only ever see its own rows: the filter is inside
the signature, so it cannot be edited client-side, and C<expires_at> makes it
expire on its own.

=head1 METHODS

=head2 list

C<GET /keys>. Metadata only, never the values.

=head2 get

C<GET /keys/{id}>.

=head2 create

C<POST /keys>. Body takes C<description>, C<actions> and C<collections>, and
optionally C<expires_at> and C<value_prefix>. B<Save C<value> from the
response.>

=head2 delete

C<DELETE /keys/{id}>. Not an error if absent.

=head2 scoped

    my $key = $ts->keys->scoped($search_key, \%embedded_params);

Derives a scoped search key. Purely local: HMAC-SHA256 of the JSON parameters
under C<$search_key>, concatenated with the first four characters of that key
and the payload, all base64-encoded - the scheme Typesense expects.

C<$search_key> must be a search-only key. Signing with an admin key would hand
out admin rights.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
