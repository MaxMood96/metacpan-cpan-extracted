
use v5.26;
use warnings;
use experimental 'signatures';
use Future::AsyncAwait;
use Object::Pad ':experimental(inherit_field)';

class Sys::Async::Virt::Connection::TLS v0.0.4;

inherit Sys::Async::Virt::Connection::TCP '$_socket', '$_url';

use Carp qw(croak);
use Future::IO::TLS;
use Log::Any qw($log);

use Crypt::OpenSSL3::SSL;
use Crypt::OpenSSL3::SSL::Context;
use Protocol::Sys::Virt::URI; # imports parse_url

field $_tls              = undef;
field $_need_tls_confirm = 1;

method _default_port() {
    return 16514;
}

async method connect() {
    # disect URL
    my %components = parse_url( $_url );

    await $self->SUPER::connect();

    my $no_verify    = $components{query}->{no_verify};
    my $pkipath      = $components{query}->{pkipath};
    my $tls_priority = $components{query}->{tls_priority};
    my $cacert;
    my $clientcert;
    my $clientkey;

    if ($pkipath) {
        $cacert     = "$pkipath/cacert.pem";
        $clientcert = "$pkipath/clientcert.pem";
        $clientkey  = "$pkipath/clientkey.pem";
    }
    else {
        if ($> != 0) {
            if (-r "$ENV{HOME}/.pki/cacert.pem") {
                $cacert = "$ENV{HOME}/.pki/cacert.pem";
            }
            if (-r "$ENV{HOME}/.pki/libvirt/clientcert.pem"
                and -r "$ENV{HOME}/.pki/libvirt/clientkey.pem") {
                $clientcert = "$ENV{HOME}/.pki/libvirt/clientcert.pem";
                $clientkey  = "$ENV{HOME}/.pki/libvirt/clientkey.pem";
            }
        }
        $cacert     = '/etc/pki/CA/cacert.pem';
        $clientcert = '/etc/pki/libvirt/clientcert.pem';
        $clientkey  = '/etc/pki/libvirt/clientkey.pem';
    }

    my $ctx = Crypt::OpenSSL3::SSL::Context->new;
    $ctx->load_verify_file( $cacert );;
    $ctx->use_PrivateKey_file( $clientkey, Crypt::OpenSSL3::SSL::FILETYPE_PEM );
    $ctx->use_certificate_file( $clientcert, Crypt::OpenSSL3::SSL::FILETYPE_PEM );

    $_tls = await Future::IO::TLS->start_TLS(
        $_socket,
        hostname => $components{host},
        context  => $ctx,
        );
}

async method _read_internal( $len ) {
    # Once we can have transitive inheritance, we can
    # add the first-byte verification to $_read_f in
    # connect().
    if ($_need_tls_confirm) {
        $_need_tls_confirm = 0;
        my $buf = await $_tls->read( $_socket, 1 );
        croak 'Server failed TLS verification'
            if $buf ne "\1";
    }
    my $data = '';
    do {
        my $read = await $_tls->read( $_socket, $len );
        unless (defined $read) {
            return ($data ? $data : undef);
        }
        $len -= length($read);
    } while ($len > 0);
    return $data;
}

async method _write_internal( $data ) {
    my $len = length($data);
    my $idx = 0;
    while ($len > 0) {
        my $written = await $_tls->write( $_socket, substr( $data, $idx ) );
        $idx += $written;
        $len -= $written;
    }
}

method is_secure() {
    return 1;
}

1;


__END__

=head1 NAME

Sys::Async::Virt::Connection::TLS - Connection to LibVirt server over TLS sockets

=head1 VERSION

v0.0.4

=head1 SYNOPSIS

  use v5.26;
  use Future::AsyncAwait;
  use Sys::Async::Virt::Connection::Factory;

  my $factory = Sys::Async::Virt::Connection::Factory->new;
  my $conn    = $factory->create_connection( 'qemu+tls://example.com/system' );

=head1 DESCRIPTION

This module connects to a remote LibVirt server through a TLS socket. This transport
uses an encrypted TLS connection to libvirt, which is the default when no transport
is specified.

This module requires L<Future::IO::Resolver> to operate fully asynchronous;
in case this module is unavailable, the C<getaddrinfo> function from L<Socket>
is used - which is a blocking function call.

=head1 URL PARAMETERS

This connection driver supports these additional parameters,
as per L<LibVirt's documentation|https://libvirt.org/uri.html#tls-transport>.

=over 8

=item * C<tls_priority>

=item * C<no_verify>

=item * C<pkipath>

=back

=head1 CONSTRUCTOR

=head2 new

Not to be called directly. Instantiated via the connection factory
(L<Sys::Async::Virt::Connection::Factory>).

=head1 METHODS

=head2 connect

  await $conn->connect;

=head2 is_secure

  my $bool = $conn->is_secure;

Returns C<true>.

=head1 BUGS AND LIMITAITIONS

=over 8

=item * Missing support for the C<tls_priority> URL query parameter

=item * Missing support for the C<no_verify> URL query parameter

=item * No verification of the server parameters

=item * No support for L<multiple parallel certificates|https://libvirt.org/kbase/tlscerts.html#multiple-parallel-certificate-identities>

=back

=head1 SEE ALSO

L<LibVirt|https://libvirt.org>, L<Sys::Virt>

=head1 LICENSE AND COPYRIGHT


  Copyright (C) 2024-2026 Erik Huelsmann

All rights reserved. This program is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
