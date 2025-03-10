use strict;
use warnings;

package URI::cpan::author 1.009;

use parent qw(URI::cpan);

sub validate {
  my ($self) = @_;

  my ($author, @rest) = split m{/}, $self->_p_rel;

  Carp::croak "invalid cpan URI: trailing path elements in $self" if @rest;

  Carp::croak "invalid cpan URI: invalid author part in $self"
    unless $author =~ m{\A[A-Z]+\z};
}

sub author {
  my ($self) = @_;
  my ($author) = split m{/}, $self->_p_rel;
  return $author;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

URI::cpan::author

=head1 VERSION

version 1.009

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should
work on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to
lower the minimum required perl.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
