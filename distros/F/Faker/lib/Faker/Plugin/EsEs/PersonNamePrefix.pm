package Faker::Plugin::EsEs::PersonNamePrefix;

use 5.018;

use strict;
use warnings;

use Venus::Class 'base';

base 'Faker::Plugin::EsEs';

# VERSION

our $VERSION = '1.19';

# METHODS

sub execute {
  my ($self, $data) = @_;

  return lc($self->faker->person_gender) eq 'male'
    ? $self->faker->random->select(data_for_name_prefix_male())
    : $self->faker->random->select(data_for_name_prefix_female());
}

sub data_for_name_prefix_male {
  state $name_prefix = [
    'Señor',
  ]
}

sub data_for_name_prefix_female {
  state $name_prefix = [
    'Señora',
    'Señorita',
  ]
}

1;



=head1 NAME

Faker::Plugin::EsEs::PersonNamePrefix - Person Name Prefix

=cut

=head1 ABSTRACT

Person Name Prefix for Faker

=cut

=head1 VERSION

1.19

=cut

=head1 SYNOPSIS

  package main;

  use Faker::Plugin::EsEs::PersonNamePrefix;

  my $plugin = Faker::Plugin::EsEs::PersonNamePrefix->new;

  # bless(..., "Faker::Plugin::EsEs::PersonNamePrefix")

=cut

=head1 DESCRIPTION

This package provides methods for generating fake data for person name prefix.

=encoding utf8

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Faker::Plugin::EsEs>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 execute

  execute(HashRef $data) (Str)

The execute method returns a returns a random fake person name prefix.

I<Since C<1.10>>

=over 4

=item execute example 1

  package main;

  use Faker::Plugin::EsEs::PersonNamePrefix;

  my $plugin = Faker::Plugin::EsEs::PersonNamePrefix->new;

  # bless(..., "Faker::Plugin::EsEs::PersonNamePrefix")

  # my $result = $plugin->execute;

  # 'Señor';

  # my $result = $plugin->execute;

  # 'Señora';

  # my $result = $plugin->execute;

  # 'Señora';

=back

=cut

=head2 new

  new(HashRef $data) (Plugin)

The new method returns a new instance of the class.

I<Since C<1.10>>

=over 4

=item new example 1

  package main;

  use Faker::Plugin::EsEs::PersonNamePrefix;

  my $plugin = Faker::Plugin::EsEs::PersonNamePrefix->new;

  # bless(..., "Faker::Plugin::EsEs::PersonNamePrefix")

=back

=cut

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut

=head1 LICENSE

Copyright (C) 2000, Al Newkirk.

This program is free software, you can redistribute it and/or modify it under
the terms of the Apache license version 2.0.

=cut