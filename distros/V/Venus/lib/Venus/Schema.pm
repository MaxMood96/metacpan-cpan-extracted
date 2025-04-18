package Venus::Schema;

use 5.018;

use strict;
use warnings;

use Venus::Class 'attr', 'base';

base 'Venus::Kind::Utility';

# ATTRIBUTES

attr 'definition';

# BUILDERS

sub build_args {
  my ($self, $data) = @_;

  if (keys %$data == 1 && exists $data->{definition}) {
    return $data;
  }
  return {
    definition => $data,
  };
}

# METHODS

sub assert {
  my ($self) = @_;

  require Venus::Assert;

  my $assert = Venus::Assert->new;

  return $assert->expression($assert->render('hashkeys', $self->definition));
}

sub check {
  my ($self, $data) = @_;

  my $assert = $self->assert;

  return $assert->valid($data);
}

sub deduce {
  my ($self, $data) = @_;

  require Venus::Type;

  my $assert = $self->assert;

  return Venus::Type->new($assert->validate($data))->deduce_deep;
}

sub error {
  my ($self, $data) = @_;

  my $error = $self->catch('validate', $data);

  die $error if $error && !$error->isa('Venus::Check::Error');

  return $error;
}

sub validate {
  my ($self, $data) = @_;

  my $assert = $self->assert;

  return $assert->validate($data);
}

1;



=head1 NAME

Venus::Schema - Schema Class

=cut

=head1 ABSTRACT

Schema Class for Perl 5

=cut

=head1 SYNOPSIS

  package main;

  use Venus::Schema;

  my $schema = Venus::Schema->new;

  # bless({...}, 'Venus::Schema')

=cut

=head1 DESCRIPTION

This package provides methods for validating whether objects and complex data
structures conform to a schema.

=cut

=head1 ATTRIBUTES

This package has the following attributes:

=cut

=head2 definition

  definition(hashref $data) (hashref)

The definition attribute is read-write, accepts C<(HashRef)> values, and is
optional.

I<Since C<2.55>>

=over 4

=item definition example 1

  # given: synopsis

  package main;

  my $definition = $schema->definition({});

  # {}

=back

=over 4

=item definition example 2

  # given: synopsis

  # given: example-1 definition

  package main;

  $definition = $schema->definition;

  # {}

=back

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Venus::Kind::Utility>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 assert

  assert() (Venus::Assert)

The assert method builds and returns a L<Venus::Assert> object based on the
L</definition>.

I<Since C<2.55>>

=over 4

=item assert example 1

  # given: synopsis

  package main;

  my $assert = $schema->assert;

  # bless({...}, 'Venus::Assert')

=back

=over 4

=item assert example 2

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
  });

  my $assert = $schema->assert;

  # bless({...}, 'Venus::Assert')

=back

=cut

=head2 check

  check(hashref $data) (boolean)

The check method builds an assert object using L</assert> and returns the
result of the L<Venus::Assert/check> method.

I<Since C<2.55>>

=over 4

=item check example 1

  # given: synopsis

  package main;

  my $check = $schema->check;

  # false

=back

=over 4

=item check example 2

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $check = $schema->check({});

  # false

=back

=over 4

=item check example 3

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $check = $schema->check({
    name => 'someone',
    role => {},
  });

  # false

=back

=over 4

=item check example 4

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $check = $schema->check({
    name => 'someone',
    role => {
      title => 'engineer',
      level => 1,
    },
  });

  # true

=back

=cut

=head2 deduce

  deduce(hashref $data) (Venus::Hash)

The deduce method builds an assert object using L</assert> and validates the
value provided using L<Venus::Assert/validate>, passing the result to
L<Venus::Type/deduce_deep> unless the validation throws an exception.

I<Since C<2.55>>

=over 4

=item deduce example 1

  # given: synopsis

  package main;

  my $deduce = $schema->deduce;

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item deduce example 2

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $deduce = $schema->deduce({});

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item deduce example 3

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $deduce = $schema->deduce({
    name => 'someone',
    role => {},
  });

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item deduce example 4

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $deduce = $schema->deduce({
    name => 'someone',
    role => {
      title => 'engineer',
      level => 1,
    },
  });

  # bless({...}, 'Venus::Hash')

=back

=cut

=head2 error

  error(hashref $data) (Venus::Error)

The error method builds an assert object using L</assert> and validates the
value provided using L<Venus::Assert/validate>, catching any error thrown and
returning it, otherwise returning undefined.

I<Since C<2.55>>

=over 4

=item error example 1

  # given: synopsis

  package main;

  my $error = $schema->error;

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item error example 2

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $error = $schema->error({});

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item error example 3

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $error = $schema->error({
    name => 'someone',
    role => {},
  });

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item error example 4

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $error = $schema->error({
    name => 'someone',
    role => {
      title => 'engineer',
      level => 1,
    },
  });

  # undef

=back

=cut

=head2 validate

  validate(hashref $data) (hashref)

The validate method builds an assert object using L</assert> and validates the
value provided using L<Venus::Assert/validate>, returning the result unless the
validation throws an exception.

I<Since C<2.55>>

=over 4

=item validate example 1

  # given: synopsis

  package main;

  my $validate = $schema->validate;

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item validate example 2

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $validate = $schema->validate({});

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item validate example 3

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $validate = $schema->validate({
    name => 'someone',
    role => {},
  });

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item validate example 4

  # given: synopsis

  package main;

  $schema->definition({
    name => 'string',
    role => {
      title => 'string',
      level => 'number',
    },
  });

  my $validate = $schema->validate({
    name => 'someone',
    role => {
      title => 'engineer',
      level => 1,
    },
  });

  # {name => 'someone', role => {title => 'engineer', level => 1,},}

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