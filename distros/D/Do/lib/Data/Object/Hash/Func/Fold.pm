package Data::Object::Hash::Func::Fold;

use 5.014;

use strict;
use warnings;

use Data::Object 'Class';

extends 'Data::Object::Hash::Func';

our $VERSION = '1.88'; # VERSION

# BUILD

has arg1 => (
  is => 'ro',
  isa => 'HashLike',
  req => 1
);

has arg2 => (
  is => 'ro',
  isa => 'StringLike',
  opt => 1
);

has arg3 => (
  is => 'ro',
  isa => 'HashLike',
  opt => 1
);

has arg4 => (
  is => 'ro',
  isa => 'HashLike',
  opt => 1
);

# METHODS

sub execute {
  my ($self) = @_;

  my ($data, $path, $store, $cache) = $self->unpack;

  my $folded = _folding($data, $path, $store, $cache);

  return $folded;
}

sub mapping {
  return ('arg1', 'arg2', 'arg3', 'arg4');
}

# PRIVATE

sub _folding {
  my ($data, $path, $store, $cache) = @_;

  $store ||= {};
  $cache ||= {};

  my $ref = ref($data);
  my $obj = Scalar::Util::blessed($data);
  my $adr = Scalar::Util::refaddr($data);
  my $tmp = {%$cache};

  if ($adr && $tmp->{$adr}) {
    $store->{$path} = $data;
  } elsif ($ref eq 'HASH' || ($obj and $obj->isa('Data::Object::Hash'))) {
    $tmp->{$adr} = 1;
    if (%$data) {
      for my $key (sort(keys %$data)) {
        my $place = $path ? join('.', $path, $key) : $key;
        my $value = $data->{$key};
        _folding($value, $place, $store, $tmp);
      }
    } else {
      $store->{$path} = {};
    }
  } elsif ($ref eq 'ARRAY' || ($obj and $obj->isa('Data::Object::Array'))) {
    $tmp->{$adr} = 1;
    if (@$data) {
      for my $idx (0 .. $#$data) {
        my $place = $path ? join(':', $path, $idx) : $idx;
        my $value = $data->[$idx];
        _folding($value, $place, $store, $tmp);
      }
    } else {
      $store->{$path} = [];
    }
  } else {
    $store->{$path} = $data if $path;
  }

  return $store;
}

1;

=encoding utf8

=head1 NAME

Data::Object::Hash::Func::Fold

=cut

=head1 ABSTRACT

Data-Object Hash Function (Fold) Class

=cut

=head1 SYNOPSIS

  use Data::Object::Hash::Func::Fold;

  my $func = Data::Object::Hash::Func::Fold->new(@args);

  $func->execute;

=cut

=head1 DESCRIPTION

Data::Object::Hash::Func::Fold is a function object for Data::Object::Hash.

=cut

=head1 INHERITANCE

This package inherits behaviors from:

L<Data::Object::Hash::Func>

=cut

=head1 LIBRARIES

This package uses type constraints defined by:

L<Data::Object::Library>

=cut

=head1 ATTRIBUTES

This package has the following attributes.

=cut

=head2 arg1

  arg1(Object)

The attribute is read-only, accepts C<(Object)> values, and is optional.

=cut

=head2 arg2

  arg2(StringLike)

The attribute is read-only, accepts C<(StringLike)> values, and is optional.

=cut

=head2 arg3

  arg3(HashLike)

The attribute is read-only, accepts C<(HashLike)> values, and is optional.

=cut

=head2 arg4

  arg4(HashLike)

The attribute is read-only, accepts C<(HashLike)> values, and is optional.

=cut

=head1 METHODS

This package implements the following methods.

=cut

=head2 execute

  execute() : Object

Executes the function logic and returns the result.

=over 4

=item execute example

  my $data = Data::Object::Hash->new({3,[4,5,6],7,{8,8,9,9}});

  my $func = Data::Object::Hash::Func::Fold->new(
    arg1 => $data
  );

  my $result = $func->execute;

=back

=cut

=head2 mapping

  mapping() : (Str)

Returns the ordered list of named function object arguments.

=over 4

=item mapping example

  my @data = $self->mapping;

=back

=cut

=head1 CREDITS

Al Newkirk, C<+319>

Anthony Brummett, C<+10>

Adam Hopkins, C<+2>

José Joaquín Atria, C<+1>

=cut

=head1 AUTHOR

Al Newkirk, C<awncorp@cpan.org>

=head1 LICENSE

Copyright (C) 2011-2019, Al Newkirk, et al.

This is free software; you can redistribute it and/or modify it under the terms
of the The Apache License, Version 2.0, as elucidated here,
https://github.com/iamalnewkirk/do/blob/master/LICENSE.

=head1 PROJECT

L<Wiki|https://github.com/iamalnewkirk/do/wiki>

L<Project|https://github.com/iamalnewkirk/do>

L<Initiatives|https://github.com/iamalnewkirk/do/projects>

L<Milestones|https://github.com/iamalnewkirk/do/milestones>

L<Contributing|https://github.com/iamalnewkirk/do/blob/master/CONTRIBUTE.mkdn>

L<Issues|https://github.com/iamalnewkirk/do/issues>

=head1 SEE ALSO

To get the most out of this distribution, consider reading the following:

L<Do>

L<Data::Object>

L<Data::Object::Class>

L<Data::Object::ClassHas>

L<Data::Object::Role>

L<Data::Object::RoleHas>

L<Data::Object::Library>

=cut