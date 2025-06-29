# -*- cperl -*-
# ABSTRACT: LaTeX token sequence object


use strict;
use warnings;
package SpeL::Object::TokenSequence;

use parent 'Exporter';
use Carp;

use Data::Dumper;



sub read {
  my $self = shift;
  my ( $level ) = @_;

  my $tokensequence = $self->{''};
  $tokensequence =~ s/~+/ /g;
  $tokensequence =~ s/\\\$/dollar/g;
  $tokensequence =~ s/\\%/ percent/g;
  $tokensequence =~ s/\\_/_/g;
  return $tokensequence;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SpeL::Object::TokenSequence - LaTeX token sequence object

=head1 VERSION

version 20250511.1428

=head1 METHODS

=head2 new()

We keep the default method, as the object is generated by the parser.

=head2 read( level )

returns a string with the spoken version of the node

=over 4

=item level: parsing level

=back

=head1 SYNOPSYS

Represents a LaTeX token sequence

=head1 AUTHOR

Walter Daems <wdaems@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2025 by Walter Daems.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=head1 CONTRIBUTOR

=for stopwords Paul Levrie

Paul Levrie

=cut
