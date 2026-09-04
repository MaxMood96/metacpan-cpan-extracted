package Wasm::Wasmtime::Extern;

use strict;
use warnings;
use 5.008004;
use FFI::C::Util qw( c_to_perl );
use Carp ();
use Wasm::Wasmtime::FFI;

require Wasm::Wasmtime::Func;
require Wasm::Wasmtime::Global;
require Wasm::Wasmtime::Table;
require Wasm::Wasmtime::Memory;

# ABSTRACT: Wasmtime extern class
our $VERSION = '0.24'; # VERSION


use constant is_func   => 0;
use constant is_global => 0;
use constant is_table  => 0;
use constant is_memory => 0;

sub kind { die "internal error" }

my %CLASS_FOR_KIND = (
  func   => 'Wasm::Wasmtime::Func',
  global => 'Wasm::Wasmtime::Global',
  table  => 'Wasm::Wasmtime::Table',
  memory => 'Wasm::Wasmtime::Memory',
);

my %DATA_CLASS = (
  func   => 'Wasm::Wasmtime::FuncData',
  global => 'Wasm::Wasmtime::GlobalData',
  table  => 'Wasm::Wasmtime::TableData',
  memory => 'Wasm::Wasmtime::MemoryData',
);


sub from_extern
{
  my(undef, $extern, $store, $owner) = @_;
  my $kind = $Wasm::Wasmtime::FFI::EXTERN_KIND{$extern->kind};
  my $class = $CLASS_FOR_KIND{$kind || ''}
    or Carp::croak("unsupported extern kind: @{[ $extern->kind ]}");
  my $data_class = $DATA_CLASS{$kind};
  my $data = $data_class->new( c_to_perl($extern->of->$kind) );
  bless { data => $data, store => $store, owner => $owner }, $class;
}


sub store { shift->{store} }


sub context { shift->{store}->context }

# _fill_extern($dst) writes this object's handle into an existing
# Wasm::Wasmtime::ExternData (wasmtime_extern_t).
sub _fill_extern
{
  my($self, $extern) = @_;
  my $kind = $self->kind;
  $extern->kind($Wasm::Wasmtime::FFI::EXTERN_KIND_NUM{$kind});
  my $slot = $extern->of->$kind;
  my $src  = c_to_perl($self->{data});
  $slot->$_($src->{$_}) for keys %$src;
  $extern;
}


sub to_extern
{
  my($self) = @_;
  $self->_fill_extern(Wasm::Wasmtime::ExternData->new);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Wasm::Wasmtime::Extern - Wasmtime extern class

=head1 VERSION

version 0.24

=head1 SYNOPSIS

 use Wasm::Wasmtime;
 
 my $store = Wasm::Wasmtime::Store->new;
 my $instance = Wasm::Wasmtime::Instance->new(
   Wasm::Wasmtime::Module->new($store->engine, wat => q{
     (module
       (func (export "foo") (param i32 i32) (result i32)
         local.get 0
         local.get 1
         i32.add)
       (memory (export "bar") 2 3)
     )
   }),
   $store,
 );
 
 my $foo = $instance->exports->foo;
 print $foo->kind, "\n";  # func
 
 my $bar = $instance->exports->bar;
 print $bar->kind, "\n";  # memory

=head1 DESCRIPTION

This class represents an object exported from or imported into a L<Wasm::Wasmtime::Instance>.
This class cannot be created independently, but subclasses of this class can be retrieved from
the L<Wasm::Wasmtime::Instance> object.  This is a base class and cannot be instantiated on its own.

In the modern Wasmtime C API an "extern" is a small tagged union value
(C<wasmtime_extern_t>) rather than a heap object.  Each concrete subclass
(L<Wasm::Wasmtime::Func>, L<Wasm::Wasmtime::Memory>, L<Wasm::Wasmtime::Global>,
L<Wasm::Wasmtime::Table>) wraps the corresponding store-handle struct plus a
reference to the owning L<Wasm::Wasmtime::Store>.

=head1 METHODS

=head2 kind

 my $string = $extern->kind;

Returns the extern kind as a string: C<func>, C<global>, C<table> or C<memory>.

=head2 is_func

=head2 is_global

=head2 is_table

=head2 is_memory

Return true for the matching kind.

=head2 from_extern

 my $obj = Wasm::Wasmtime::Extern->from_extern($extern_data, $store);

Internal: given a C<wasmtime_extern_t> struct (a L<Wasm::Wasmtime::FFI>
C<Wasm::Wasmtime::ExternData>) and the owning L<Wasm::Wasmtime::Store>, returns a
L<Wasm::Wasmtime::Func>, C<::Global>, C<::Table> or C<::Memory> object holding a
private copy of the handle.

=head2 store

 my $store = $extern->store;

Returns the L<Wasm::Wasmtime::Store> that owns this extern.

=head2 context

 my $context = $extern->context;

Returns the C<wasmtime_context_t> pointer for this extern's store (internal use).

=head2 to_extern

 my $extern_data = $extern->to_extern;

Internal: returns a fresh L<Wasm::Wasmtime::FFI> C<Wasm::Wasmtime::ExternData>
(a C<wasmtime_extern_t>) populated from this object's handle, for use as an
import or with C<< Wasm::Wasmtime::Linker->define >>.

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
