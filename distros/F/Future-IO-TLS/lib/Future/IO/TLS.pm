package Future::IO::TLS;
$Future::IO::TLS::VERSION = '0.001';
use 5.020;
use warnings;
use experimental 'signatures';

use Crypt::OpenSSL3::SSL;
use Crypt::OpenSSL3::SSL::Context;
use Future::AsyncAwait;

my $context = Crypt::OpenSSL3::SSL::Context->new;
$context->set_default_verify_paths;

async sub start_TLS($class, $handle, %options) {
	my $my_context = $options{context} // $context;
	my $ssl = Crypt::OpenSSL3::SSL->new($my_context);
	my ($inner, $pipe) = Crypt::OpenSSL3::BIO->new_bio_pair(8192, 8192);
	$ssl->set_rbio($inner);
	$ssl->set_wbio($inner);
	$ssl->set_mode(Crypt::OpenSSL3::SSL::MODE_ENABLE_PARTIAL_WRITE | Crypt::OpenSSL3::SSL::MODE_ACCEPT_MOVING_WRITE_BUFFER);

	if (my $hostname = $options{hostname}) {
		$ssl->set_verify(Crypt::OpenSSL3::SSL::VERIFY_PEER);
		$ssl->set_tlsext_host_name($hostname);
		$ssl->set_host($hostname);
	}
	$ssl->use_PrivateKey_file($options{private_key_file}, Crypt::OpenSSL3::SSL::FILETYPE_PEM) if $options{private_key_file};
	$ssl->use_certificate_chain_file($options{certificate_chain_file}) if $options{certificate_chain_file};

	my $set_state_method = $options{server} ? 'set_accept_state' : 'set_connect_state';
	$ssl->$set_state_method;

	while (1) {
		my $ret = $ssl->do_handshake;
		last if $ret >= 0;

		if (my $pending = $pipe->pending) {
			my $hello = $pipe->read($pending);
			await Future::IO->write_exactly($handle, $hello);
		}

		die "TLS Error" if $ssl->get_error($ret) == Crypt::OpenSSL3::SSL::ERROR_SSL;

		my $encrypted = await Future::IO->read($handle, 4096);
		die "Socket terminated" if not defined $encrypted;
		$pipe->write($encrypted);
	}

	my $verify = $ssl->get_verify_result;
	die $verify->error_string if not $verify->ok;

	return bless { ssl => $ssl, pipe => $pipe }, $class;
}

async sub connect($class, $handle, $sockaddr, %options) {
	await Future::IO->connect($handle, $sockaddr);
	return await $class->start_TLS($handle, server => 0, %options);
}

async sub accept($class, $handle, $sockaddr, %options) {
	await Future::IO->accept($handle, $sockaddr);
	return await $class->start_TLS($handle, server => 1, %options);
}

async sub read($self, $handle, $size) {
	while (1) {
		my $ret = $self->{ssl}->read(my $buffer, $size);
		return $buffer if $ret > 0;

		my $error = $self->{ssl}->get_error($ret);
		if ($error == Crypt::OpenSSL3::SSL::ERROR_WANT_READ) {
			my $encrypted = await Future::IO->read($handle, $size + 24);
			$self->{pipe}->write($encrypted); # now retry reading
		} elsif ($error == Crypt::OpenSSL3::SSL::ERROR_WANT_WRITE) {
			my $data = $self->{pipe}->read($self->{pipe}->pending);
			await Future::IO->write_exactly($handle, $data);
		} else {
			die "TLS Error: " . $self->{ssl}->get_error($ret);
		}
	}
}

async sub write($self, $handle, $payload) {
	my $offset = 0;
	while ($offset < length $payload) {
		my $written = $self->{ssl}->write(substr $payload, $offset);

		if ($written > 0) {
			my $encrypted = $self->{pipe}->read($self->{pipe}->pending);
			await Future::IO->write_exactly($handle, $encrypted);
			$offset += $written;
		} else {
			my $error = $self->{ssl}->get_error($written);

			if ($error == Crypt::OpenSSL3::SSL::ERROR_WANT_WRITE) {
				my $data = $self->{pipe}->read($self->{pipe}->pending);
				await Future::IO->write_exactly($handle, $data);
			} elsif ($error == Crypt::OpenSSL3::SSL::ERROR_WANT_READ) {
				my $encrypted = await Future::IO->read($handle, 4096);
				$self->{pipe}->write($encrypted);
			} else {
				die "TLS Error: " . $self->{ssl}->get_error($written);
			}
		}
	}
	return $offset;
}

1;

# ABSTRACT: A TLS interface for Future::IO

__END__

=pod

=encoding UTF-8

=head1 NAME

Future::IO::TLS - A TLS interface for Future::IO

=head1 VERSION

version 0.001

=head1 SYNOPSIS

 use Future::IO;
 Future::IO->load_best_impl;
 use Future::AsyncAwait;

 use Future::IO::TLS;
 use Future::IO::Resolver;

 async sub main($hostname, $secure) {
   my $port = $secure ? 'https' : 'http';
   my ($address) = await Future::IO::Resolver->getaddrinfo(host => $hostname, service => $port) or die;

   socket my $connection, $address->{family}, $address->{socktype}, $address->{protocol} or die;
   await Future::IO->connect($connection, $address->{addr});
   my $ssl = $secure ? await Future::IO::TLS->start_TLS($connection, hostname => $hostname) : 'Future::IO';

   await $ssl->write($connection, "GET / HTTP/1.1\r\nHost: $hostname\r\n\r\n");
   my $response = await $ssl->read($connection, 2048);

   say $response;
 };

 my $main = main('www.google.com', 1);
 $main->get;

=head1 DESCRIPTION

This is a fully asynchronous TLS implementation for L<Future::IO>, based on L<Crypt::OpenSSL3>.

=head1 METHODS

=head2 start_TLS

 my $tls = Future::IO::TLS->start_TLS($fh, %options);

This initiates a TLS handshake to upgrade the connection to using TLS. It will return a TLS connection object that should be used as invocant instead of C<Future::IO> when calling C<read> or C<write>.

It takes the following optional named arguments:

=over 4

=item * server

If true the connection will take the accepting role in the handshake, otherwise it will take the connecting role.

=item * context

An L<TLS Context|Crypt::OpenSSL3::SSL::Context> used to base connections on. 

=item * hostname

The hostname of the other side of the connection. Typically used for client connections.

=item * private_key_file

The location of the private key file. Typically used for server connections.

=item * certificate_chain_file

The location of the certificate chain file. Typically used for server connections.

=back

=head2 connect

 my $tls = Future::IO::TLS->connect($fh, $sockaddr, %options);

This combines C<< Future::IO->connect >> with C<< Future::IO::TLS->start_TLS >>. You probably want to pass this a C<hostname> parameter, otherwise the peer's identity can't be verified.

=head2 accept

 my $tls = Future::IO::TLS->accept($fh, $sockaddr, %options);

This combines C<< Future::IO->accept >> with C<< Future::IO::TLS->start_TLS >>. You probably want to pass this the C<private_key_file> and C<certificate_chain_file> arguments.

=head2 read

 my $data = await $io->read($fh, $size);

Read C<$size> bytes from C<$fh> using TLS.

=head2 write

 my $written = await $io->write($fh, $data);

Write C<$data> to C<$fh> using TLS.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
