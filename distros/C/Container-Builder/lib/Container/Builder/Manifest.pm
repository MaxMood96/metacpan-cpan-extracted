package Container::Builder::Manifest;

use v5.40;
use feature 'class';
no warnings 'experimental::class';

use Crypt::Digest::SHA256 qw(sha256_hex);
use JSON;

class Container::Builder::Manifest {
	field $digest = '';
	field $size = '';

	method generate_manifest($config_digest, $config_size, $layers) {
		my @layers_arr = ();
		foreach(@$layers) {
			my %entry = (
				mediaType => $_->get_media_type(),
				digest => 'sha256:' . $_->get_digest(),
				size => $_->get_size()
			);
			push @layers_arr, \%entry;
		}
		my %config = (
			mediaType => 'application/vnd.oci.image.config.v1+json',
			digest => 'sha256:' . $config_digest,
			size => $config_size
		);
		my %manifest = (
			schemaVersion => 2,
			mediaType => 'application/vnd.oci.image.manifest.v1+json',
			config => \%config,
			layers => \@layers_arr
		);
		my $json = encode_json(\%manifest);

		$digest = Crypt::Digest::SHA256::sha256_hex($json);
		$size = length($json);
		return $json;
	}

	method get_digest() { return lc($digest) }
	method get_size() { return $size }
}

1;
__END__

=encoding utf-8

=pod

=head1 NAME

Container::Builder::Manifest - Class for the container Index specification.

=head1 DESCRIPTION

Container::Builder::Manifest provides a JSON file of the container Manifest.

=head1 METHODS

=over 1

=item generate_manifest($config_digest, $config_size, $layers)

Generate a JSON string for a OCI manifest file. C<$config_digest> needs to be the hex representation of the SHA256 of the config JSON file. C<$layers> is an array ref to a list of C<Container::Builder::Layer> objects.

=item get_digest()

Returns the SHA256 digest of the generated config.

=item get_size()

Returns the size (length) of the generated config.

=back

=head1 AUTHOR

Adriaan Dens E<lt>adri@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2026- Adriaan Dens

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item Part of the L<Container::Builder> module.

=item L<https://github.com/opencontainers/image-spec/blob/main/manifest.md>

=back

=cut

