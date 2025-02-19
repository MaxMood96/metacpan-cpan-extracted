package FFI::C::FFI;

use strict;
use warnings;
use FFI::Platypus 1.24;
use constant ();
use base qw( Exporter );

# ABSTRACT: Private module for FFI::C
our $VERSION = '0.15'; # VERSION


our @EXPORT_OK = qw( malloc free memset memcpy_addr );

my $ffi = FFI::Platypus->new( api => 1, lib => [undef] );

constant->import( memcpy_addr => $ffi->find_symbol( 'memcpy' ) );

$ffi->attach( malloc => ['size_t']                => 'opaque', '$'   );
$ffi->attach( free   => ['opaque']                => 'void',   '$'   );
$ffi->attach( memset => ['opaque','int','size_t'] => 'opaque', '$$$' );

## should this be configurable for when we hunt for memory leaks?
#sub malloc ($)
#{
#  $ffi->function( malloc => ['size_t'] => 'opaque' )
#      ->call(@_);
#}
#
#sub free ($)
#{
#  $ffi->function( free => ['opaque'] => 'void' )
#      ->call(@_);
#}
#
#sub memset ($$$)
#{
#  $ffi->function( memset => ['opaque','int','size_t'] => 'opaque' )
#      ->call(@_);
#}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

FFI::C::FFI - Private module for FFI::C

=head1 VERSION

version 0.15

=head1 SYNOPSIS

 perldoc FFI::C

=head1 DESCRIPTION

This module is private for L<FFI::C>

=head1 SEE ALSO

=over 4

=item L<FFI::C>

=item L<FFI::C::Array>

=item L<FFI::C::ArrayDef>

=item L<FFI::C::Def>

=item L<FFI::C::File>

=item L<FFI::C::PosixFile>

=item L<FFI::C::Struct>

=item L<FFI::C::StructDef>

=item L<FFI::C::Union>

=item L<FFI::C::UnionDef>

=item L<FFI::C::Util>

=item L<FFI::Platypus::Record>

=back

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020-2022 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
