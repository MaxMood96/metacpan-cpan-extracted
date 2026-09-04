package Wasm::Wasmtime::Table;

use strict;
use warnings;
use 5.008004;
use base qw( Wasm::Wasmtime::Extern );
use Ref::Util qw( is_blessed_ref is_plain_arrayref );
use Wasm::Wasmtime::FFI;
use Wasm::Wasmtime::Store;
use Wasm::Wasmtime::TableType;
use Carp ();
use constant is_table => 1;
use constant kind => 'table';

# ABSTRACT: Wasmtime table class
our $VERSION = '0.24'; # VERSION


$ffi_prefix = 'wasmtime_table_';

sub _null_val
{
  my($kind) = @_;
  my $num = $Wasm::Wasmtime::FFI::VAL_KIND_NUM{$kind};
  Carp::croak("cannot create table of element type $kind") unless defined $num;
  my $val = Wasm::Wasmtime::Val->new;
  $val->kind($num);
  $val;  # zeroed union == null funcref / null externref
}


$ffi->attach( [ wasmtime_table_new => 'new' ] => ['opaque', 'wasm_tabletype_t', 'wasmtime_val_t', 'wasmtime_table_t'] => 'wasmtime_error_t' => sub {
  my $xsub = shift;
  my $class = shift;
  my($store, $tabletype) = @_;
  Carp::croak("Wasm::Wasmtime::Table->new requires a Wasm::Wasmtime::Store")
    unless is_blessed_ref($store) && $store->isa('Wasm::Wasmtime::Store');
  my $init = _null_val($tabletype->element->kind);
  my $data = Wasm::Wasmtime::TableData->new;
  if(my $error = $xsub->($store->context, $tabletype, $init, $data))
  {
    Carp::croak($error->message);
  }
  bless { data => $data, store => $store }, $class;
});


$ffi->attach( [ wasmtime_table_type => 'type' ] => ['opaque', 'wasmtime_table_t'] => 'wasm_tabletype_t' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_table_size => 'size' ] => ['opaque', 'wasmtime_table_t'] => 'uint64' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_table_get => 'get' ] => ['opaque', 'wasmtime_table_t', 'uint64', 'wasmtime_val_t'] => 'bool' => sub {
  my($xsub, $self, $index) = @_;
  my $val = Wasm::Wasmtime::Val->new;
  return undef unless $xsub->($self->context, $self->{data}, $index, $val);
  $val->to_perl;
});


$ffi->attach( [ wasmtime_table_grow => 'grow' ] => ['opaque', 'wasmtime_table_t', 'uint64', 'wasmtime_val_t', 'uint64*'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $delta) = @_;
  my $init = _null_val($self->type->element->kind);
  my $prev = 0;
  my $error = $xsub->($self->context, $self->{data}, $delta, $init, \$prev);
  $error ? !!0 : !!1;
});

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Wasm::Wasmtime::Table - Wasmtime table class

=head1 VERSION

version 0.24

=head1 SYNOPSIS

 use Wasm::Wasmtime;
 
 my $store = Wasm::Wasmtime::Store->new;
 my $instance = Wasm::Wasmtime::Instance->new(
   Wasm::Wasmtime::Module->new($store->engine, wat => q{
     (module
       (table (export "table") 1 funcref)
     )
   }),
   $store,
 );
 
 my $table = $instance->exports->table;
 print $table->type->element->kind, "\n";   # funcref
 print $table->size, "\n";                  # 1

=head1 DESCRIPTION

B<WARNING>: WebAssembly and Wasmtime are a moving target and the interface for these modules
is under active development.  Use with caution.

This class represents a WebAssembly table object.

Note that Perl-space marshalling of C<funcref> / C<externref> table elements is
limited; L</get> currently returns C<undef> for reference values.

=head1 CONSTRUCTOR

=head2 new

 my $table = Wasm::Wasmtime::Table->new(
   $store,       # Wasm::Wasmtime::Store
   $tabletype,   # Wasm::Wasmtime::TableType
 );

Creates a new table whose elements are initialized to null.

=head1 METHODS

=head2 type

 my $tabletype = $table->type;

Returns the L<Wasm::Wasmtime::TableType> object for this table object.

=head2 size

 my $size = $table->size;

Returns the size of the table in elements.

=head2 get

 my $value = $table->get($index);

Returns the value at C<$index>, or C<undef> if the index is out of bounds (or the
element is a reference value that cannot be represented in Perl).

=head2 grow

 my $bool = $table->grow($delta);

Grows the table by C<$delta> null elements.  Returns true on success.

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
