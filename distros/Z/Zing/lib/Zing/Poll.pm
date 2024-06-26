package Zing::Poll;

use 5.014;

use strict;
use warnings;

use registry 'Zing::Types';
use routines;

use Data::Object::Class;
use Data::Object::ClassHas;

use Time::HiRes ();

our $VERSION = '0.27'; # VERSION

# ATTRIBUTES

has 'repo' => (
  is => 'ro',
  isa => 'Repo',
  req => 1,
);

# METHODS

method await(Int $secs) {
  my $data;
  my $repo = $self->repo;
  my @tres = (Time::HiRes::gettimeofday);
  my $time = join('', $tres[0] + $secs, $tres[1]);

  until ($data = $repo->recv) {
    last if join('', Time::HiRes::gettimeofday) >= $time;
  }

  return $data;
}

1;



=encoding utf8

=head1 NAME

Zing::Poll - Blocking Receive

=cut

=head1 ABSTRACT

Blocking Receive Construct

=cut

=head1 SYNOPSIS

  use Zing::Poll;
  use Zing::KeyVal;

  my $poll = Zing::Poll->new(repo => Zing::KeyVal->new(name => 'notes'));

  # $poll->await(0);

=cut

=head1 DESCRIPTION

This package provides an algorithm for preforming a blocking receive by polling
the datastore for a specific item.

=cut

=head1 LIBRARIES

This package uses type constraints from:

L<Zing::Types>

=cut

=head1 ATTRIBUTES

This package has the following attributes:

=cut

=head2 repo

  repo(Repo)

This attribute is read-only, accepts C<(Repo)> values, and is required.

=cut

=head1 METHODS

This package implements the following methods:

=cut

=head2 await

  await(Int $secs) : Maybe[HashRef]

The await method polls the datastore specified for the data at the key
specified, for at-least the number of seconds specified, and returns the data
or undefined.

=over 4

=item await example #1

  # given: synopsis

  $poll->await(0);

=back

=over 4

=item await example #2

  # given: synopsis

  $poll->repo->send({ task => 'write research paper' });

  $poll->await(0);

=back

=cut

=head1 AUTHOR

Al Newkirk, C<awncorp@cpan.org>

=head1 LICENSE

Copyright (C) 2011-2019, Al Newkirk, et al.

This is free software; you can redistribute it and/or modify it under the terms
of the The Apache License, Version 2.0, as elucidated in the L<"license
file"|https://github.com/cpanery/zing/blob/master/LICENSE>.

=head1 PROJECT

L<Wiki|https://github.com/cpanery/zing/wiki>

L<Project|https://github.com/cpanery/zing>

L<Initiatives|https://github.com/cpanery/zing/projects>

L<Milestones|https://github.com/cpanery/zing/milestones>

L<Contributing|https://github.com/cpanery/zing/blob/master/CONTRIBUTE.md>

L<Issues|https://github.com/cpanery/zing/issues>

=cut
