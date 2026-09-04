package Wasm::Wasmtime::Linker;

use strict;
use warnings;
use 5.008004;
use FFI::Platypus::Buffer qw( scalar_to_buffer );
use Wasm::Wasmtime::FFI;
use Wasm::Wasmtime::Store;
use Wasm::Wasmtime::Extern;
use Wasm::Wasmtime::Instance;
use Wasm::Wasmtime::Func;
use Wasm::Wasmtime::Trap;
use Ref::Util qw( is_blessed_ref );
use Carp ();

# ABSTRACT: Wasmtime linker class
our $VERSION = '0.24'; # VERSION


$ffi_prefix = 'wasmtime_linker_';
$ffi->load_custom_type('::PtrObject' => 'wasmtime_linker_t' => __PACKAGE__);


$ffi->attach( new => ['wasm_engine_t'] => 'wasmtime_linker_t' => sub {
  my($xsub, $class, $store) = @_;
  Carp::croak("Wasm::Wasmtime::Linker->new requires a Wasm::Wasmtime::Store")
    unless is_blessed_ref($store) && $store->isa('Wasm::Wasmtime::Store');
  my $self = $xsub->($store->engine);
  $self->{store} = $store;
  $self;
});


$ffi->attach( allow_shadowing => [ 'wasmtime_linker_t', 'bool' ] => 'void' => sub {
  my($xsub, $self, $value) = @_;
  $xsub->($self, $value);
  $self;
});


$ffi->attach( define => ['wasmtime_linker_t', 'opaque', 'opaque', 'size_t', 'opaque', 'size_t', 'wasmtime_extern_t'] => 'wasmtime_error_t' => sub {
  my $xsub   = shift;
  my $self   = shift;
  my($module, $name, $extern) = @_;

  Carp::croak("not an extern: $extern")
    unless is_blessed_ref($extern) && $extern->isa('Wasm::Wasmtime::Extern');

  my $mod = defined $module ? "$module" : "";
  my $nam = defined $name   ? "$name"   : "";
  my($mptr, $mlen) = scalar_to_buffer($mod);
  my($nptr, $nlen) = scalar_to_buffer($nam);
  my $e = $extern->to_extern;
  if(my $error = $xsub->($self, $self->store->context, $mptr, $mlen, $nptr, $nlen, $e))
  {
    Carp::croak($error->message);
  }
  $self;
});


$ffi->attach( define_wasi => ['wasmtime_linker_t'] => 'wasmtime_error_t' => sub {
  my($xsub, $self) = @_;
  if(my $error = $xsub->($self))
  {
    Carp::croak($error->message);
  }
  $self;
});


$ffi->attach( define_instance => ['wasmtime_linker_t', 'opaque', 'opaque', 'size_t', 'wasmtime_instance_t'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $name, $instance) = @_;
  my $nam = defined $name ? "$name" : "";
  my($nptr, $nlen) = scalar_to_buffer($nam);
  if(my $error = $xsub->($self, $self->store->context, $nptr, $nlen, $instance->{data}))
  {
    Carp::croak($error->message);
  }
  $self;
});


$ffi->attach( instantiate => ['wasmtime_linker_t','opaque','wasmtime_module_t','wasmtime_instance_t','opaque*'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $module) = @_;
  my $data = Wasm::Wasmtime::InstanceData->new;
  my $trap;
  if(my $error = $xsub->($self, $self->store->context, $module, $data, \$trap))
  {
    die Wasm::Wasmtime::Trap->from_error($error);
  }
  die Wasm::Wasmtime::Trap->new($trap) if $trap;
  return Wasm::Wasmtime::Instance->_new_from_data($data, $self->store, $module);
});


$ffi->attach( [ get => 'get_one_by_name' ] => ['wasmtime_linker_t','opaque','opaque','size_t','opaque','size_t','wasmtime_extern_t'] => 'bool' => sub {
  my($xsub, $self, $module, $name) = @_;
  my $mod = defined $module ? "$module" : "";
  my $nam = defined $name   ? "$name"   : "";
  my($mptr, $mlen) = scalar_to_buffer($mod);
  my($nptr, $nlen) = scalar_to_buffer($nam);
  my $extern = Wasm::Wasmtime::ExternData->new;
  $xsub->($self, $self->store->context, $mptr, $mlen, $nptr, $nlen, $extern)
    or Carp::croak("no such item in linker: $mod\::$nam");
  my $obj = Wasm::Wasmtime::Extern->from_extern($extern, $self->store);
  $extern->free;
  $obj;
});


$ffi->attach( get_default => ['wasmtime_linker_t','opaque','opaque','size_t','wasmtime_func_t'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $name) = @_;
  my $nam = defined $name ? "$name" : "";
  my($nptr, $nlen) = scalar_to_buffer($nam);
  my $data = Wasm::Wasmtime::FuncData->new;
  if(my $error = $xsub->($self, $self->store->context, $nptr, $nlen, $data))
  {
    Carp::croak($error->message);
  }
  bless { data => $data, store => $self->store }, 'Wasm::Wasmtime::Func';
});


sub store { shift->{store} }

_generate_destroy('wasmtime_linker_delete');

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Wasm::Wasmtime::Linker - Wasmtime linker class

=head1 VERSION

version 0.24

=head1 SYNOPSIS

 use Wasm::Wasmtime;
 
 my $store  = Wasm::Wasmtime::Store->new;
 my $linker = Wasm::Wasmtime::Linker->new($store);
 
 # Configure WASI on the store and define the WASI imports in the linker
 $store->set_wasi(
   Wasm::Wasmtime::WasiConfig
     ->new
     ->inherit_stdout
 );
 $linker->define_wasi;
 
 # Create a logger module + instance
 my $logger = $linker->instantiate(
   Wasm::Wasmtime::Module->new(
     $store->engine,
     wat => q{
       (module
         (type $fd_write_ty (func (param i32 i32 i32 i32) (result i32)))
         (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (type $fd_write_ty)))
 
         (func (export "log") (param i32 i32)
           ;; store the pointer in the first iovec field
           i32.const 4
           local.get 0
           i32.store
 
           ;; store the length in the first iovec field
           i32.const 4
           local.get 1
           i32.store offset=4
 
           ;; call the `fd_write` import
           i32.const 1     ;; stdout fd
           i32.const 4     ;; iovs start
           i32.const 1     ;; number of iovs
           i32.const 0     ;; where to write nwritten bytes
           call $fd_write
           drop
         )
 
         (memory (export "memory") 2)
         (global (export "memory_offset") i32 (i32.const 65536))
       )
     },
   )
 );
 $linker->define_instance("logger", $logger);
 
 # Create a caller module + instance
 my $caller = $linker->instantiate(
   Wasm::Wasmtime::Module->new(
     $store->engine,
     wat => q{
       (module
         (import "logger" "log" (func $log (param i32 i32)))
         (import "logger" "memory" (memory 1))
         (import "logger" "memory_offset" (global $offset i32))
 
         (func (export "run")
           ;; Our `data` segment initialized our imported memory, so let's print the
           ;; string there now.
           global.get $offset
           i32.const 14
           call $log
         )
 
         (data (global.get $offset) "Hello, world!\n")
       )
     },
   ),
 );
 $caller->exports->run->();

=head1 DESCRIPTION

B<WARNING>: WebAssembly and Wasmtime are a moving target and the interface for these modules
is under active development.  Use with caution.

This class represents a WebAssembly linker.

=head1 CONSTRUCTOR

=head2 new

 my $linker = Wasm::Wasmtime::Linker->new(
   $store,        # Wasm::Wasmtime::Store
 );

Create a new WebAssembly linker object.

=head1 METHODS

=head2 allow_shadowing

 $linker->allow_shadowing($bool);

=head2 define

 $linker->define($module, $name, $extern);

Define the given extern (a L<Wasm::Wasmtime::Func>, C<::Memory>, C<::Global> or C<::Table>).

=head2 define_wasi

 $linker->define_wasi;

Define the WASI imports in this linker.  The WASI state itself must be
configured on the store with C<< $store->set_wasi($wasi_config) >>.  Any
argument is accepted and ignored for backwards compatibility.

=head2 define_instance

 $linker->define_instance($name, $instance);

=head2 instantiate

 my $instance = $linker->instantiate($module);

Instantiate the module using the linker.  Returns a L<Wasm::Wasmtime::Instance>.

=head2 get_one_by_name

 my $extern = $linker->get_one_by_name($module, $name);

Returns the L<Wasm::Wasmtime::Extern> for the given C<$module> and C<$name>.
Throws an exception if there is no such item.

=head2 get_default

 my $func = $linker->get_default($name);

Acquires the "default export" of the named module.  Returns a L<Wasm::Wasmtime::Func>.

=head2 store

 my $store = $linker->store;

Returns the L<Wasm::Wasmtime::Store> for the linker.

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
