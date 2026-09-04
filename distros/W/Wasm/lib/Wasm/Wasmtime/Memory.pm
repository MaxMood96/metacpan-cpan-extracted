package Wasm::Wasmtime::Memory;

use strict;
use warnings;
use 5.008004;
use base qw( Wasm::Wasmtime::Extern );
use Ref::Util qw( is_blessed_ref is_plain_arrayref );
use Wasm::Wasmtime::FFI;
use Wasm::Wasmtime::Store;
use Wasm::Wasmtime::MemoryType;
use Carp ();
use constant is_memory => 1;
use constant kind => 'memory';

# ABSTRACT: Wasmtime memory class
our $VERSION = '0.24'; # VERSION


$ffi_prefix = 'wasmtime_memory_';


$ffi->attach( [ wasmtime_memory_new => 'new' ] => ['opaque', 'wasm_memorytype_t', 'wasmtime_memory_t'] => 'wasmtime_error_t' => sub {
  my $xsub = shift;
  my $class = shift;
  my($store, $memorytype) = @_;
  Carp::croak("Wasm::Wasmtime::Memory->new requires a Wasm::Wasmtime::Store")
    unless is_blessed_ref($store) && $store->isa('Wasm::Wasmtime::Store');
  $memorytype = Wasm::Wasmtime::MemoryType->new($memorytype)
    if is_plain_arrayref $memorytype;
  my $data = Wasm::Wasmtime::MemoryData->new;
  if(my $error = $xsub->($store->context, $memorytype, $data))
  {
    Carp::croak($error->message);
  }
  bless { data => $data, store => $store }, $class;
});


$ffi->attach( [ wasmtime_memory_type => 'type' ] => ['opaque', 'wasmtime_memory_t'] => 'wasm_memorytype_t' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_memory_data => 'data' ] => ['opaque', 'wasmtime_memory_t'] => 'opaque' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_memory_data_size => 'data_size' ] => ['opaque', 'wasmtime_memory_t'] => 'size_t' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_memory_size => 'size' ] => ['opaque', 'wasmtime_memory_t'] => 'uint64' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_memory_grow => 'grow' ] => ['opaque', 'wasmtime_memory_t', 'uint64', 'uint64*'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $delta) = @_;
  my $prev = 0;
  my $error = $xsub->($self->context, $self->{data}, $delta, \$prev);
  if($error)
  {
    # match the old boolean-ish behaviour
    return !!0;
  }
  return !!1;
});

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Wasm::Wasmtime::Memory - Wasmtime memory class

=head1 VERSION

version 0.24

=head1 SYNOPSIS

 use Wasm::Wasmtime;
 use PeekPoke::FFI qw( poke );
 
 my $store = Wasm::Wasmtime::Store->new;
 
 # create a new memory object with a minumum
 # of 3 pages and maximum of 9
 my $memory = Wasm::Wasmtime::Memory->new(
   $store,
   Wasm::Wasmtime::MemoryType->new([3,9]),
 );
 
 poke($memory->data + 10, 42);                   # store the byte 42 at offset
                                                 # 10 inside the data region
 
 printf "data_size = %x\n", $memory->data_size;  # 30000
 printf "size      = %d\n", $memory->size;       # 3
 
 $memory->grow(4);                               # increase data region by 4 pages
 
 printf "data_size = %x\n", $memory->data_size;  # 70000
 printf "size      = %d\n", $memory->size;       # 7

=head1 DESCRIPTION

B<WARNING>: WebAssembly and Wasmtime are a moving target and the interface for these modules
is under active development.  Use with caution.

This class represents a WebAssembly memory object.

=head1 CONSTRUCTOR

=head2 new

 my $memory = Wasm::Wasmtime::Memory->new(
   $store,      # Wasm::Wasmtime::Store
   $memorytype, # Wasm::Wasmtime::MemoryType
 );

Creates a new memory object.

=head1 METHODS

=head2 type

 my $memorytype = $memory->type;

Returns the L<Wasm::Wasmtime::MemoryType> object for this memory object.

=head2 data

 my $pointer = $memory->data;

Returns a pointer (as an integer) to the start of the memory.

=head2 data_size

 my $size = $memory->data_size;

Returns the current size of the memory in bytes.

=head2 size

 my $size = $memory->size;

Returns the current size of the memory in pages.

=head2 grow

 my $bool = $memory->grow($delta);

Tries to increase the page size by the given C<$delta>.  Returns true on success, false otherwise.

=head1 SEE ALSO

=over 4

=item L<Wasm>

=item L<Wasm::Wasmtime>

=back

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020-2026 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
