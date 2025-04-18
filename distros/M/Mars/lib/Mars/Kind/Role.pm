package Mars::Kind::Role;

use 5.018;

use strict;
use warnings;

use base 'Mars::Kind';

# METHODS

sub BUILD {
  my ($self, @data) = @_;

  no strict 'refs';

  my @roles = @{$self->META->roles};

  for my $action (grep defined, map *{"${_}::BUILD"}{"CODE"}, @roles) {
    $self->$action(@data);
  }

  return $self;
}

sub DESTROY {
  my ($self, @data) = @_;

  no strict 'refs';

  my @roles = @{$self->META->roles};

  for my $action (grep defined, map *{"${_}::DESTROY"}{"CODE"}, @roles) {
    $self->$action(@data);
  }

  return $self;
}

sub EXPORT {
  my ($self, $into) = @_;

  return [];
}

sub IMPORT {
  my ($self, $into) = @_;

  no strict 'refs';
  no warnings 'redefine';

  for my $name (grep !*{"${into}::${_}"}{"CODE"}, @{$self->EXPORT($into)}) {
    *{"${into}::${name}"} = \&{"@{[$self->NAME]}::${name}"};
  }

  return $self;
}

sub does {
  my ($self, @args) = @_;

  return $self->DOES(@args);
}

sub meta {
  my ($self) = @_;

  return $self->META;
}

1;



=head1 NAME

Mars::Kind::Role - Role Base Class

=cut

=head1 ABSTRACT

Role Base Class for Perl 5

=cut

=head1 SYNOPSIS

  package Person;

  use base 'Mars::Kind::Role';

  package User;

  use base 'Mars::Kind::Class';

  package main;

  my $user = User->ROLE('Person')->new(
    fname => 'Elliot',
    lname => 'Alderson',
  );

  # bless({fname => 'Elliot', lname => 'Alderson'}, 'User')

=cut

=head1 DESCRIPTION

This package provides a role base class with role building and object
construction lifecycle hooks.

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Mars::Kind>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 does

  does(Str $name) (Bool)

The does method returns true if the object is composed of the role provided.

I<Since C<0.01>>

=over 4

=item does example 1

  package Employee;

  use base 'Mars::Kind::Role';

  Employee->ROLE('Person');

  package main;

  my $user = User->ROLE('Employee')->new(
    fname => 'Elliot',
    lname => 'Alderson',
  );

  my $does = Employee->does('Person');

  # 1

=back

=cut

=head2 meta

  meta() (Meta)

The meta method returns a L<Mars::Meta> objects which describes the package's
configuration.

I<Since C<0.01>>

=over 4

=item meta example 1

  package main;

  my $user = User->ROLE('Person')->new(
    fname => 'Elliot',
    lname => 'Alderson',
  );

  my $meta = Person->meta;

  # bless({...}, 'Mars::Meta')

=back

=cut

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut