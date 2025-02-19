package Venus::Role::Makeable;

use 5.018;

use strict;
use warnings;

use Venus::Role 'with';

# BUILDERS

sub BUILD {
  my ($self, $data) = @_;

  $data = $self->making($data);

  for my $name (keys %$data) {
    $self->{$name} = $data->{$name};
  }

  return $self;
};

# METHODS

sub makers {
  my ($self) = @_;

  return {};
}

sub make_args {
  my ($self, $data, $spec) = @_;

  for my $name (grep exists($data->{$_}), sort keys %$spec) {
    $data->{$name} = $self->make_onto(
      $data, $name, $spec->{$name}, $data->{$name},
    );
  }

  return $data;
}

sub make_attr {
  my ($self, $name, @args) = @_;

  return $self->{$name} if !@args;

  return $self->{$name} = $self->making({$name, $args[0]})->{$name};
}

sub make_into {
  my ($self, $class, $value) = @_;

  require Scalar::Util;
  require Venus::Space;

  $class = (my $space = Venus::Space->new($class))->load;

  my $name = lc $space->label;

  if (my $method = $self->can("make_into_${name}")) {
    return $self->$method($class, $value);
  }
  if (Scalar::Util::blessed($value) && $value->isa($class)) {
    return $value;
  }
  else {
    return $class->make($value);
  }
}

sub make_onto {
  my ($self, $data, $name, $class, $value) = @_;

  require Venus::Space;

  $class = Venus::Space->new($class)->load;

  $value = $data->{$name} if $#_ < 4;

  if (my $method = $self->can("make_${name}")) {
    return $data->{$name} = $self->$method(\&make_into, $class, $value);
  }
  else {
    return $data->{$name} = $self->make_into($class, $value);
  }
}

sub making {
  my ($self, $data) = @_;

  my $spec = $self->makers;

  return $data if !%$spec;

  return $self->make_args($data, $spec);
}

# EXPORTS

sub EXPORT {
  [
    'make_args',
    'make_attr',
    'make_into',
    'make_onto',
    'makers',
    'making',
  ]
}

1;



=head1 NAME

Venus::Role::Makeable - Makeable Role

=cut

=head1 ABSTRACT

Makeable Role for Perl 5

=cut

=head1 SYNOPSIS

  package Person;

  use Venus::Class 'attr', 'error', 'with';

  with 'Venus::Role::Makeable';

  attr 'name';
  attr 'father';
  attr 'mother';
  attr 'siblings';

  sub make {
    my ($self, $value) = @_;

    error if !ref $value;

    return $self->new($value);
  }

  sub makers {
    {
      father => 'Person',
      mother => 'Person',
      name => 'Venus/String',
      siblings => 'Person',
    }
  }

  sub make_name {
    my ($self, $code, @args) = @_;

    return $self->$code(@args);
  }

  sub make_siblings {
    my ($self, $code, $class, $value) = @_;

    return [map $self->$code($class, $_), @$value];
  }

  package main;

  my $person = Person->make({
    name => 'me',
    father => {name => 'father'},
    mother => {name => 'mother'},
    siblings => [{name => 'brother'}, {name => 'sister'}],
  });

  # $person
  # bless({...}, 'Person')

  # $person->name
  # bless({...}, 'Venus::String')

  # $person->father
  # bless({...}, 'Person')

  # $person->mother
  # bless({...}, 'Person')

  # $person->siblings
  # [bless({...}, 'Person'), bless({...}, 'Person'), ...]

=cut

=head1 DESCRIPTION

This package modifies the consuming package and provides methods for hooking
into object construction and coercing arguments into objects and values using
the I<"make"> protocol, i.e. using the C<"make"> method (which performs fatal
type checking and coercions) instead of the typical C<"new"> method.

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 make_args

  make_args(hashref $data, hashref $spec) (hashref)

The make_args method replaces values in the data provided with objects
corresponding to the specification provided. The specification should contains
key/value pairs where the keys map to class attributes (or input parameters)
and the values are L<Venus::Space> compatible package names.

I<Since C<1.30>>

=over 4

=item make_args example 1

  package main;

  my $person = Person->new;

  my $data = $person->make_args(
    {
      father => { name => 'father' }
    },
    {
      father => 'Person',
    },
  );

  # {
  #   father   => bless({...}, 'Person'),
  # }

=back

=cut

=head2 make_attr

  make_attr(string $name, any $value) (any)

The make_attr method is a surrogate accessor and gets and/or sets an instance
attribute based on the C<makers> rules, returning the made value.

I<Since C<1.30>>

=over 4

=item make_attr example 1

  # given: synopsis

  package main;

  $person = Person->new(
    name => 'me',
  );

  my $make_name = $person->make_attr('name');

  # bless({value => "me"}, "Venus::String")

=back

=over 4

=item make_attr example 2

  # given: synopsis

  package main;

  $person = Person->new(
    name => 'me',
  );

  my $make_name = $person->make_attr('name', 'myself');

  # bless({value => "myself"}, "Venus::String")

=back

=cut

=head2 make_into

  make_into(string $class, any $value) (object)

The make_into method attempts to build and return an object based on the
class name and value provided, unless the value provided is already an object
derived from the specified class.

I<Since C<1.30>>

=over 4

=item make_into example 1

  package main;

  my $person = Person->new;

  my $friend = $person->make_into('Person', {
    name => 'friend',
  });

  # bless({...}, 'Person')

=back

=cut

=head2 make_onto

  make_onto(hashref $data, string $name, string $class, any $value) (object)

The make_onto method attempts to build and assign an object based on the
class name and value provided, as the value corresponding to the name
specified, in the data provided. If the C<$value> is omitted, the value
corresponding to the name in the C<$data> will be used.

I<Since C<1.30>>

=over 4

=item make_onto example 1

  package main;

  my $person = Person->new;

  my $data = { friend => { name => 'friend' } };

  my $friend = $person->make_onto($data, 'friend', 'Person');

  # bless({...}, 'Person'),

  # $data was updated
  #
  # {
  #   friend => bless({...}, 'Person'),
  # }

=back

=over 4

=item make_onto example 2

  package Player;

  use Venus::Class;

  with 'Venus::Role::Makeable';

  attr 'name';
  attr 'teammates';

  sub makers {
    {
      teammates => 'Person',
    }
  }

  sub make_into_person {
    my ($self, $class, $value) = @_;

    return $class->make($value);
  }

  sub make_into_venus_string {
    my ($self, $class, $value) = @_;

    return $class->make($value);
  }

  sub make_teammates {
    my ($self, $code, $class, $value) = @_;

    return [map $self->$code($class, $_), @$value];
  }

  package main;

  my $player = Player->new;

  my $data = { teammates => [{ name => 'player2' }, { name => 'player3' }] };

  my $teammates = $player->make_onto($data, 'teammates', 'Person');

  # [bless({...}, 'Person'), bless({...}, 'Person')]

  # $data was updated
  #
  # {
  #   teammates => [bless({...}, 'Person'), bless({...}, 'Person')],
  # }

=back

=cut

=head2 makers

  makers() (hashref)

The makers method, if defined, is called during object construction, or by the
L</making> method, and returns key/value pairs where the keys map to class
attributes (or input parameters) and the values are L<Venus::Space> compatible
package names.

I<Since C<1.30>>

=over 4

=item makers example 1

  package main;

  my $person = Person->new(
    name => 'me',
  );

  my $makers = $person->makers;

  # {
  #   father   => "Person",
  #   mother   => "Person",
  #   name     => "Venus/String",
  #   siblings => "Person",
  # }

=back

=cut

=head2 making

  making(hashref $data) (hashref)

The making method is called automatically during object construction but can
be called manually as well, and is passed a hashref to make and return.

I<Since C<1.30>>

=over 4

=item making example 1

  package main;

  my $person = Person->new;

  my $making = $person->making({
    name => 'me',
  });

  # $making
  # {...}

  # $making->{name}
  # bless({...}, 'Venus::String')

  # $making->{father}
  # undef

  # $making->{mother}
  # undef

  # $making->{siblings}
  # undef

=back

=over 4

=item making example 2

  package main;

  my $person = Person->new;

  my $making = $person->making({
    name => 'me',
    mother => {name => 'mother'},
    siblings => [{name => 'brother'}, {name => 'sister'}],
  });

  # $making
  # {...}

  # $making->{name}
  # bless({...}, 'Venus::String')

  # $making->{father}
  # undef

  # $making->{mother}
  # bless({...}, 'Person')

  # $making->{siblings}
  # [bless({...}, 'Person'), bless({...}, 'Person'), ...]

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