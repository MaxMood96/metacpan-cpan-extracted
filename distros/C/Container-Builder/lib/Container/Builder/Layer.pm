package Container::Builder::Layer;

use v5.40;
use feature 'class';
no warnings 'experimental::class';

class Container::Builder::Layer {
	field $comment :param = '';

	# This method is called in the builder to generate the artifact (bytes on disk) that will be put in the container image
	method generate_artifact() { }

	# These three methods are used by the manifest to generate the layers array
	method get_comment() { $comment }
	method get_media_type() { }
	method get_digest() { }
	method get_size() { }
}

1;
__END__

=encoding utf-8

=pod

=head1 NAME

Container::Builder::Layer - Class for Container::Builder layers.

=head1 DESCRIPTION

Container::Builder::Layer provides an abstract class for Container::Builder layers.

=head1 METHODS

=over 1

=item new(comment => 'this is a layer')

Create a C<Container::Builder::Layer> object. The comment argument is put inside the Container config JSON so that tools like L<dive|https://github.com/wagoodman/dive> can show a meaningful name for the layer.

=item generate_artifact()

This method is called in the C<Container::Builder> to generate the artifact that will be put in the container image. It needs to return a valid layer (TAR or TAR GZIP).

=item get_comment()

Return the comment that was passed in the constructor.

=item get_media_type()

Return the media type of the container. This is the	mime type of the layer. Possibilities are C<application/vnd.oci.image.layer.v1.tar> or C<application/vnd.oci.image.layer.v1.tar+gzip>.

=item get_digest()

Returns the SHA256 digest of the generated layer.

=item get_size()

Returns the size (length) of the generated layer.

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

=item L<https://github.com/opencontainers/image-spec/blob/main/layer.md>

=back

=cut

