package Path::Resolver::Resolver::Mux::Ordered 3.100455;
# ABSTRACT: multiplex resolvers by checking them in order
use Moose;

use namespace::autoclean;

use MooseX::Types;
use MooseX::Types::Moose qw(Any ArrayRef);

#pod =head1 SYNOPSIS
#pod
#pod   my $resolver = Path::Resolver::Resolver::Mux::Ordered->new({
#pod     resolvers => [
#pod       $resolver_1,
#pod       $resolver_2,
#pod       ...
#pod     ],
#pod   });
#pod
#pod   my $simple_entity = $resolver->entity_at('foo/bar.txt');
#pod
#pod This resolver looks in each of its resolvers in order and returns the result of
#pod the first of its sub-resolvers to find the named entity.  If no entity is
#pod found, it returns false as usual.
#pod
#pod The default native type of this resolver is Any, meaning that is is much more
#pod lax than other resolvers.  A C<native_type> can be specified while creating the
#pod resolver.
#pod
#pod =attr resolvers
#pod
#pod This is an array of other resolvers.  When asked for content, the Mux::Ordered
#pod resolver will check each resolver in this array and return the first found
#pod content, or false if none finds any content.
#pod
#pod =method unshift_resolver
#pod
#pod This method will add a resolver to the beginning of the list of consulted
#pod resolvers.
#pod
#pod =method push_resolver
#pod
#pod This method will add a resolver to the end of the list of consulted resolvers.
#pod
#pod =cut

has resolvers => (
  is  => 'ro',
  isa => ArrayRef[ role_type('Path::Resolver::Role::Resolver') ],
  required   => 1,
  auto_deref => 1,
  traits => ['Array'],
  handles  => {
    push_resolver => 'push',
    unshift_resolver => 'unshift',
  },
);

has native_type => (
  is  => 'ro',
  isa => class_type('Moose::Meta::TypeConstraint'),
  default  => sub { Any },
  required => 1,
);

with 'Path::Resolver::Role::Resolver';

sub entity_at {
  my ($self, $path) = @_;

  for my $resolver ($self->resolvers) {
    my $entity = $resolver->entity_at($path);
    next unless defined $entity;
    return $entity;
  }

  return;
}
  
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Path::Resolver::Resolver::Mux::Ordered - multiplex resolvers by checking them in order

=head1 VERSION

version 3.100455

=head1 SYNOPSIS

  my $resolver = Path::Resolver::Resolver::Mux::Ordered->new({
    resolvers => [
      $resolver_1,
      $resolver_2,
      ...
    ],
  });

  my $simple_entity = $resolver->entity_at('foo/bar.txt');

This resolver looks in each of its resolvers in order and returns the result of
the first of its sub-resolvers to find the named entity.  If no entity is
found, it returns false as usual.

The default native type of this resolver is Any, meaning that is is much more
lax than other resolvers.  A C<native_type> can be specified while creating the
resolver.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 ATTRIBUTES

=head2 resolvers

This is an array of other resolvers.  When asked for content, the Mux::Ordered
resolver will check each resolver in this array and return the first found
content, or false if none finds any content.

=head1 METHODS

=head2 unshift_resolver

This method will add a resolver to the beginning of the list of consulted
resolvers.

=head2 push_resolver

This method will add a resolver to the end of the list of consulted resolvers.

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
