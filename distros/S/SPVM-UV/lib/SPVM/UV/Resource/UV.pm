package SPVM::UV::Resource::UV;



1;

=encoding utf8

=head1 Name

SPVM::UV::Resource::UV - Data Structure for UV class and libuv

=head1 Description

UV::Resource::UV class in L<SPVM> is a L<resource|SPVM::Document::Resource> class for data structure for UV class and libuv.

=head1 Usage

MyClass.build:
  
  my $config = SPVM::Builder::Config->new_c99;
  
  $config->use_resource('UV::Resource::UV');
  
  $config;

MyClass.c:

  #include "spvm_native.h"
  #include "spvm_uv.h"
  
  int32_t SPVM__MyClass__test(SPVM_ENV* env, SPVM_VALUE* stack) {
    
    // Use functions in foo.h
    
    return 0;
  }

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
