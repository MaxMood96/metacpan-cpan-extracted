package Venus::Vars;

use 5.018;

use strict;
use warnings;

use Venus::Class 'attr', 'base', 'with';

base 'Venus::Kind::Utility';

with 'Venus::Role::Valuable';
with 'Venus::Role::Buildable';
with 'Venus::Role::Accessible';
with 'Venus::Role::Proxyable';

# ATTRIBUTES

attr 'named';

# BUILDERS

sub build_proxy {
  my ($self, $package, $method, $value) = @_;

  my $has_value = exists $_[3];

  return sub {
    return $self->get($method) if !$has_value; # no value
    return $self->set($method, $value);
  };
}

sub build_self {
  my ($self, $data) = @_;

  $self->named({}) if !$self->named;

  return $self;
}

# METHODS

sub default {
  my ($self) = @_;

  return {%ENV};
}

sub exists {
  my ($self, $name) = @_;

  return if not defined $name;

  my $pos = $self->name($name);

  return if not defined $pos;

  return exists $self->value->{$pos};
}

sub get {
  my ($self, $name) = @_;

  return if not defined $name;

  my $pos = $self->name($name);

  return if not defined $pos;

  return $self->value->{$pos};
}

sub name {
  my ($self, $name) = @_;

  if (defined $self->named->{$name}) {
    return $self->named->{$name};
  }

  if (defined $self->value->{$name}) {
    return $name;
  }

  if (defined $self->value->{uc($name)}) {
    return uc($name);
  }

  return undef;
}

sub set {
  my ($self, $name, $data) = @_;

  return if not defined $name;

  my $pos = $self->name($name);

  return if not defined $pos;

  return $self->value->{$pos} = $data;
}

sub unnamed {
  my ($self) = @_;

  my $list = {};

  my $vars = $self->value;
  my $data = +{reverse %{$self->named}};

  for my $index (sort keys %$vars) {
    unless (exists $data->{$index}) {
      $list->{$index} = $vars->{$index};
    }
  }

  return $list;
}

1;



=head1 NAME

Venus::Vars - Vars Class

=cut

=head1 ABSTRACT

Vars Class for Perl 5

=cut

=head1 SYNOPSIS

  package main;

  use Venus::Vars;

  my $vars = Venus::Vars->new(
    value => { USER => 'awncorp', HOME => '/home/awncorp', },
    named => { iam => 'USER', root => 'HOME', },
  );

  # $vars->root; # $ENV{HOME}
  # $vars->home; # $ENV{HOME}
  # $vars->get('home'); # $ENV{HOME}
  # $vars->get('HOME'); # $ENV{HOME}

  # $vars->iam; # $ENV{USER}
  # $vars->user; # $ENV{USER}
  # $vars->get('user'); # $ENV{USER}
  # $vars->get('USER'); # $ENV{USER}

=cut

=head1 DESCRIPTION

This package provides methods for accessing C<%ENV> items.

=cut

=head1 ATTRIBUTES

This package has the following attributes:

=cut

=head2 named

  named(HashRef)

This attribute is read-write, accepts C<(HashRef)> values, is optional, and defaults to C<{}>.

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Venus::Kind::Utility>

=cut

=head1 INTEGRATES

This package integrates behaviors from:

L<Venus::Role::Accessible>

L<Venus::Role::Buildable>

L<Venus::Role::Proxyable>

L<Venus::Role::Valuable>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 default

  default() (hashref)

The default method returns the default value, i.e. C<{%ENV}>.

I<Since C<0.01>>

=over 4

=item default example 1

  # given: synopsis;

  my $default = $vars->default;

  # { USER => 'awncorp', HOME => '/home/awncorp', ... }

=back

=cut

=head2 exists

  exists(string $key) (boolean)

The exists method takes a name or index and returns truthy if an associated
value exists.

I<Since C<0.01>>

=over 4

=item exists example 1

  # given: synopsis;

  my $exists = $vars->exists('iam');;

  # 1

=back

=over 4

=item exists example 2

  # given: synopsis;

  my $exists = $vars->exists('USER');;

  # 1

=back

=over 4

=item exists example 3

  # given: synopsis;

  my $exists = $vars->exists('PATH');

  # undef

=back

=over 4

=item exists example 4

  # given: synopsis;

  my $exists = $vars->exists('user');

  # 1

=back

=cut

=head2 get

  get(string $key) (any)

The get method takes a name or index and returns the associated value.

I<Since C<0.01>>

=over 4

=item get example 1

  # given: synopsis;

  my $get = $vars->get('iam');

  # "awncorp"

=back

=over 4

=item get example 2

  # given: synopsis;

  my $get = $vars->get('USER');

  # "awncorp"

=back

=over 4

=item get example 3

  # given: synopsis;

  my $get = $vars->get('PATH');

  # undef

=back

=over 4

=item get example 4

  # given: synopsis;

  my $get = $vars->get('user');

  # "awncorp"

=back

=cut

=head2 name

  name(string $key) (string | undef)

The name method takes a name or index and returns index if the the associated
value exists.

I<Since C<0.01>>

=over 4

=item name example 1

  # given: synopsis;

  my $name = $vars->name('iam');

  # "USER"

=back

=over 4

=item name example 2

  # given: synopsis;

  my $name = $vars->name('USER');

  # "USER"

=back

=over 4

=item name example 3

  # given: synopsis;

  my $name = $vars->name('PATH');

  # undef

=back

=over 4

=item name example 4

  # given: synopsis;

  my $name = $vars->name('user');

  # "USER"

=back

=cut

=head2 set

  set(string $key, any $value) (any)

The set method takes a name or index and sets the value provided if the
associated argument exists.

I<Since C<0.01>>

=over 4

=item set example 1

  # given: synopsis;

  my $set = $vars->set('iam', 'root');

  # "root"

=back

=over 4

=item set example 2

  # given: synopsis;

  my $set = $vars->set('USER', 'root');

  # "root"

=back

=over 4

=item set example 3

  # given: synopsis;

  my $set = $vars->set('PATH', '/tmp');

  # undef

=back

=over 4

=item set example 4

  # given: synopsis;

  my $set = $vars->set('user', 'root');

  # "root"

=back

=cut

=head2 unnamed

  unnamed() (hashref)

The unnamed method returns an arrayref of values which have not been named
using the C<named> attribute.

I<Since C<0.01>>

=over 4

=item unnamed example 1

  package main;

  use Venus::Vars;

  my $vars = Venus::Vars->new(
    value => { USER => 'awncorp', HOME => '/home/awncorp', },
    named => { root => 'HOME', },
  );

  my $unnamed = $vars->unnamed;

  # { USER => "awncorp" }

=back

=cut

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut

=head1 LICENSE

Copyright (C) 2022, Awncorp, C<awncorp@cpan.org>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Apache license version 2.0.

=cut