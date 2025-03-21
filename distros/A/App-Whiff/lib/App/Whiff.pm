use strict;
use warnings;
package App::Whiff 0.008;
# ABSTRACT: find the first executable of a series of alternatives

use File::Which ();

#pod =head1 DESCRIPTION
#pod
#pod This module implements logic used by the F<whiff> command, which takes a number
#pod of command names and returns the first one that exists and is executable.
#pod
#pod =method find_first
#pod
#pod   my $filename = App::Whiff->find_first(\@names);
#pod
#pod Given an arrayref of command names (which should I<not> be anything other than
#pod base filename), this method either returns an absolute path to the first of the
#pod alternatives found in the path (using L<File::Which>) or false.
#pod
#pod =cut

sub find_first {
  my ($self, $names) = @_;

  my $file;
  for my $name (@$names) {
    return $name if $name =~ m{\A/} && -x $name;
    $file = File::Which::which($name);
    return $file if $file;
  }

  return;
}

#pod =method run
#pod
#pod This method is called by the F<whiff> program to ... well, run.
#pod
#pod =cut

sub run {
  my ($self) = @_;

  die "usage: whiff <command ...>\n" unless @ARGV;
  my $file = $self->find_first([ @ARGV ]);
  die "no alternative found\n" unless $file;
  print "$file\n";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Whiff - find the first executable of a series of alternatives

=head1 VERSION

version 0.008

=head1 DESCRIPTION

This module implements logic used by the F<whiff> command, which takes a number
of command names and returns the first one that exists and is executable.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 METHODS

=head2 find_first

  my $filename = App::Whiff->find_first(\@names);

Given an arrayref of command names (which should I<not> be anything other than
base filename), this method either returns an absolute path to the first of the
alternatives found in the path (using L<File::Which>) or false.

=head2 run

This method is called by the F<whiff> program to ... well, run.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 CONTRIBUTORS

=for stopwords Florian Schlichting Ricardo Signes

=over 4

=item *

Florian Schlichting <fsfs@debian.org>

=item *

Ricardo Signes <rjbs@semiotic.systems>

=item *

Ricardo Signes <rjbs@users.noreply.github.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
