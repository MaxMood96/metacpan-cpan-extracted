use 5.008008;
use strict;
use warnings;

package Data::Smile;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001000';

use Exporter::Tiny;
our @ISA       = qw( Exporter::Tiny );
our @EXPORT_OK = qw( encode_smile decode_smile dump_smile load_smile );

BEGIN {
	eval {
		require Data::Smile::XS;
		Data::Smile::XS->import( ':all' );
		1;
	}
	or do {
		require Data::Smile::PP;
		Data::Smile::PP->import( ':all' );
	};
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Data::Smile - encoder/decoder for Smile data

=head1 SYNOPSIS

	use Data::Smile qw( encode_smile decode_smile dump_smile load_smile );

	my $bytes = encode_smile( { hello => 'world' } );
	my $data  = decode_smile( $bytes );

	dump_smile( 'example.smile', { answer => 42 } );
	my $round_trip = load_smile( 'example.smile' );

=head1 DESCRIPTION

This module is a wrapper for L<Data::Smile::PP> and L<Data::Smile::XS>.
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

Include the module's Smile transport header before the payload.

=item * C<shared_names> (boolean, default true)

Enable the shared-name marker flag when repeated object/hash key names are
observed.

=item * C<shared_values> (boolean, default true)

Enable the shared short-string-value marker flag when repeated short,
non-UTF-8 scalar values are observed.

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

For Smile big-integer and big-decimal values, return big-number
objects (C<Math::BigInt>/C<Math::BigFloat>) instead of native
numeric scalars.

=item * C<require_header> (boolean, default false)

Require the Smile header to be present. If true and no header is found,
decoding throws an exception.

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

=head1 PERL AND XS IMPLEMENTATIONS

Data::Smile will attempt to load and use L<Data::Smile::XS> to encode
and decode Smile data. If that module is not loadable, then it will
fall back to a pure Perl implementation in L<Data::Smile::PP>.

There is currently no environment variable or other option that can
be used to manually select an implementation, but loading and using
those modules directly is supported.

Both modules are believed to fully implement version 1.0.7 of the Smile
specification.

=head1 COMPARISON WITH JSON

Smile is a binary data format which allows you to encode and decode
JSON-like data structures. That is, collections of key-value pairs
(hashes in Perl terminology, objects in JSON terminology), arrays,
strings, numbers, booleans, and null (undef in Perl terminology).

Depending on the complexity of the input data, Data::Smile may produce
output half the size (in bytes) or even less than comparable JSON data.

Data::Smile::XS runs at about 25% the speed of JSON::XS when encoding,
and roughly the same speed when decoding.

Data::Smile::PP runs at roughly the same speed as JSON::PP when encoding,
and almost three times faster when decoding.

Of course, raw encoding/decoding of JSON-like data is probably only
a small part of what your application will do. If it also needs to
POST the data over HTTPS or write it to a database over a TCP socket,
then the speed gains of having much smaller payloads can start to add
up.

=head1 BLESSED OBJECTS

Like L<JSON::PP> and L<JSON::XS>, Data::Smile will call the C<TO_JSON>
method on any blessed objects it gets passed. If you pass it a blessed
object without a C<TO_JSON> method, then the behaviour is currently
unspecified, and the behaviour may differ between the PP and XS versions.

=head1 THE SMILE HEADER

The C<encode_smile> option allows you to save four whole bytes by
omiting the usual Smile header. The Smile header consists of C<< ":)\n" >>
followed by a single byte advertising which Smile features are used
in the file.

The C<decode_smile> function supports all official Smile features, so
doesn't need the header and can happily parse headless Smile data.

Most decoders require the header to be present, including B<go-smile> (Go),
B<libsmile> (C), B<PySmile> (Python), B<smile-js> (Javascript), and
B<serde_smile> (Rust). For this reason C<encode_smile> I<will> include
the header in its output by default.

If you are encoding mostly very small pieces of data, and storing them
somewhere you know is always going to be Smile data (like a particular
column in a database which is dedicated to storing Smile data), and you
know that only Data::Smile will ever be used to parse the data, then it
may be safe to store Smile without the header. Otherwise, it's only four
bytes, so you should probably just include it.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-data-smile/issues>.

=head1 SEE ALSO

L<Data::Smile::PP>,
L<Data::Smile::XS>,
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
