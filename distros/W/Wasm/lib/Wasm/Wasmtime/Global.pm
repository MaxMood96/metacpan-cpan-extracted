package Wasm::Wasmtime::Global;

use strict;
use warnings;
use 5.008004;
use base qw( Wasm::Wasmtime::Extern );
use Ref::Util qw( is_blessed_ref );
use Wasm::Wasmtime::FFI;
use Wasm::Wasmtime::Store;
use Wasm::Wasmtime::GlobalType;
use Carp ();
use constant is_global => 1;
use constant kind => 'global';

# ABSTRACT: Wasmtime global class
our $VERSION = '0.24'; # VERSION


$ffi_prefix = 'wasmtime_global_';


$ffi->attach( [ wasmtime_global_new => 'new' ] => ['opaque', 'wasm_globaltype_t', 'wasmtime_val_t', 'wasmtime_global_t'] => 'wasmtime_error_t' => sub {
  my $xsub = shift;
  my $class = shift;
  my($store, $globaltype, $value) = @_;
  Carp::croak("Wasm::Wasmtime::Global->new requires a Wasm::Wasmtime::Store")
    unless is_blessed_ref($store) && $store->isa('Wasm::Wasmtime::Store');
  my $val = Wasm::Wasmtime::Val->from_perl($globaltype->content->kind, $value);
  my $data = Wasm::Wasmtime::GlobalData->new;
  if(my $error = $xsub->($store->context, $globaltype, $val, $data))
  {
    Carp::croak($error->message);
  }
  bless { data => $data, store => $store }, $class;
});


$ffi->attach( [ wasmtime_global_type => 'type' ] => ['opaque', 'wasmtime_global_t'] => 'wasm_globaltype_t' => sub {
  my($xsub, $self) = @_;
  $xsub->($self->context, $self->{data});
});


$ffi->attach( [ wasmtime_global_get => 'get' ] => ['opaque', 'wasmtime_global_t', 'wasmtime_val_t'] => 'void' => sub {
  my($xsub, $self) = @_;
  my $value = Wasm::Wasmtime::Val->new;
  $xsub->($self->context, $self->{data}, $value);
  $value->to_perl;
});


$ffi->attach( [ wasmtime_global_set => 'set' ] => ['opaque', 'wasmtime_global_t', 'wasmtime_val_t'] => 'wasmtime_error_t' => sub {
  my($xsub, $self, $value) = @_;
  my $val = Wasm::Wasmtime::Val->from_perl($self->type->content->kind, $value);
  if(my $error = $xsub->($self->context, $self->{data}, $val))
  {
    Carp::croak($error->message);
  }
  return;
});


sub tie
{
  my $self = shift;
  my $ref;
  tie $ref, __PACKAGE__, $self;
  \$ref;
}

sub TIESCALAR { $_[1] }
*FETCH = \&get;
*STORE = \&set;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Wasm::Wasmtime::Global - Wasmtime global class

=head1 VERSION

version 0.24

=head1 SYNOPSIS

 use Wasm::Wasmtime;
 
 my $store = Wasm::Wasmtime::Store->new;
 my $global = Wasm::Wasmtime::Global->new(
   $store,
   Wasm::Wasmtime::GlobalType->new('i32','var'),
   42,
 );
 
 print $global->get, "\n";  # 42
 $global->set(99);
 print $global->get, "\n";  # 99

=head1 DESCRIPTION

B<WARNING>: WebAssembly and Wasmtime are a moving target and the interface for these modules
is under active development.  Use with caution.

This class represents a WebAssembly global object.

=head1 CONSTRUCTOR

=head2 new

 my $global = Wasm::Wasmtime::Global->new(
   $store,      # Wasm::Wasmtime::Store
   $globaltype, # Wasm::Wasmtime::GlobalType
   $value,      # initial value
 );

Creates a new global object.

=head1 METHODS

=head2 type

 my $globaltype = $global->type;

Returns the L<Wasm::Wasmtime::GlobalType> object for this global object.

=head2 get

 my $value = $global->get;

Gets the global value.

=head2 set

 $global->set($value);

Sets the global to the given value.

=head2 tie

 my $ref = $global->tie;

Returns a reference to a tied scalar that can be used to get/set the global.

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
