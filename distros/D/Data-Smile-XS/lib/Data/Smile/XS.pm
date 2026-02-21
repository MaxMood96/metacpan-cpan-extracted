use 5.008008;
use strict;
use warnings;

package Data::Smile::XS;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001000';

require XSLoader;
XSLoader::load( __PACKAGE__, $VERSION );

use Exporter::Tiny;
our @ISA       = qw( Exporter::Tiny );
our @EXPORT_OK = qw( encode_smile decode_smile dump_smile load_smile );

sub _is_pathish_filename {
	my ( $x ) = @_;
	return 0 if not ref $x;
	return 1 if eval { $x->isa( 'Path::Tiny' ) } or eval { $x->isa( 'Path::Class::File' ) };
	return 0;
}

sub _open_for_read {
	my ( $file ) = @_;

	if ( _is_pathish_filename( $file ) ) {
		$file = "$file";
	}

	if ( not ref $file ) {
		open my $fh, '<:raw', $file or die "open($file) for read: $!";
		return ( $fh, 1 );
	}

	if ( eval { $file->can( 'read' ) } or eval { $file->can( 'getline' ) } or ref( $file ) eq 'GLOB' ) {
		binmode( $file, ':raw' );
		return ( $file, 0 );
	}

	die "Unsupported file argument for read";
}

sub _open_for_write {
	my ( $file ) = @_;

	if ( _is_pathish_filename( $file ) ) {
		$file = "$file";
	}

	if ( not ref $file ) {
		open my $fh, '>:raw', $file or die "open($file) for write: $!";
		return ( $fh, 1 );
	}

	if ( eval { $file->can( 'print' ) } or eval { $file->can( 'write' ) } or ref( $file ) eq 'GLOB' ) {
		binmode( $file, ':raw' );
		return ( $file, 0 );
	}

	die "Unsupported file argument for write";
}

sub dump_smile {
	my ( $file, $data, $opts ) = @_;
	die 'dump_smile expects at most 3 arguments' if @_ > 3;

	if ( @_ >= 3 and defined $opts ) {
		die 'Options must be a hash reference' if ref( $opts ) ne 'HASH';
	}

	my ( $fh, $close ) = _open_for_write( $file );

	my $bytes = encode_smile( $data, $opts );
	my $ok = eval {
		print {$fh} $bytes or die "write: $!";
		1;
	} ? 1 : 0;

	if ( $close ) {
		close $fh or $ok = 0;
	}

	return $ok ? 1 : 0;
}

sub load_smile {
	my ( $file, $opts ) = @_;
	die 'load_smile expects at most 2 arguments' if @_ > 2;

	if ( @_ >= 2 and defined $opts ) {
		die 'Options must be a hash reference' if ref( $opts ) ne 'HASH';
	}

	my ( $fh, $close ) = _open_for_read( $file );

	my $buf = do { local $/; <$fh> };
	die "read failed" if not defined $buf;

	if ( $close ) {
		close $fh or die "close: $!";
	}

	return defined $opts
		? decode_smile( $buf, $opts )
		: decode_smile( $buf );
}

__END__

=pod

=encoding utf-8

=head1 NAME

Data::Smile::XS - XS encoder/decoder for Smile data

=head1 SYNOPSIS

  use Data::Smile::XS qw(
    encode_smile decode_smile dump_smile load_smile
  );

  my $bytes = encode_smile( { hello => 'world' } );
  my $data  = decode_smile( $bytes );

  dump_smile( 'example.smile', { answer => 42 } );
  my $round_trip = load_smile( 'example.smile' );

=head1 DESCRIPTION

This module provides a fast XS implementation of Smile serialisation.
It exports four optional functions:

=over 4

=item * C<encode_smile>

=item * C<decode_smile>

=item * C<dump_smile>

=item * C<load_smile>

=back

All option arguments are optional hashrefs. Passing any other kind of
reference for options throws an exception.

=head1 FUNCTIONS

=head2 encode_smile( $data, \%options )

Encodes a Perl data structure into Smile bytes and returns a byte string.

Recognised options:

=over 4

=item * C<write_header> (boolean, default true)

Include the 4-byte Smile header (C<:)> C<\n> and flags byte) before the
payload.

=item * C<shared_names> (boolean, default true)

Enable shared key-name back references while encoding object/hash keys.

=item * C<shared_values> (boolean, default true when C<write_header> is true;
default false when C<write_header> is false and C<shared_values> is not
explicitly set)

Enable shared short-string value back references while encoding.

=item * C<canonical> (boolean, default false)

If true, encode hashes/objects with keys sorted lexically.

This is slower, but should (in theory) result in byte-identical output
every time, given the same input.

=back

Unknown option keys throw an exception.

=head2 decode_smile( $bytes, \%options )

Decodes Smile bytes into Perl data and returns the resulting structure.

Recognised options:

=over 4

=item * C<use_bigint> (boolean, default true)

Decode integer values outside native integer range as C<Math::BigInt>
objects (when available).

=item * C<require_header> (boolean, default false)

Require the Smile document header to be present. If true and no header is
found, decoding throws an exception.

=item * C<json_bool> (boolean, default true)

If true, decode booleans as C<JSON::PP> booleans (C<JSON::PP::true> and
C<JSON::PP::false>) when available. If false, decode booleans as native Perl
booleans.

=back

Unknown option keys throw an exception.

=head2 dump_smile( $file, $data, \%options )

Encodes C<$data> using C<encode_smile> and writes the bytes to C<$file>.
Returns true on success and false on write/close failure.

C<$file> may be:

=over 4

=item * a filename string

=item * an open writable filehandle

=item * a C<Path::Tiny> object

=item * a C<Path::Class::File> object

=back

The C<\%options> hashref is passed through to C<encode_smile>, so it accepts
the same options and defaults: C<write_header>, C<shared_names>,
C<shared_values>, and C<canonical>.

=head2 load_smile( $file, \%options )

Reads Smile bytes from C<$file>, decodes them with C<decode_smile>, and
returns the resulting data structure.

C<$file> may be:

=over 4

=item * a filename string

=item * an open readable filehandle

=item * a C<Path::Tiny> object

=item * a C<Path::Class::File> object

=back

The C<\%options> hashref is passed through to C<decode_smile>, so it accepts
the same options and defaults: C<use_bigint>, C<require_header>, and
C<json_bool>.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-data-smile-xs/issues>.

=head1 SEE ALSO

L<Data::Smile>,
L<Data::Smile::PP>,
L<https://github.com/FasterXML/smile-format-specification/blob/master/smile-specification.md>
(Smile format specification),
L<https://en.wikipedia.org/wiki/Smile_(data_interchange_format)>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2026 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
