# -*- cperl -*-
# ABSTRACT: LaTeX subscript object


package SpeL::Object::Subscript;

use SpeL::Object::MathGroup;

use SpeL::I18n;

use parent 'Exporter';
use Carp;

use Data::Dumper;



sub read {
  my $self = shift;
  my ( $level ) = @_;

  if ( defined $self->{Lit} ) {
    return ' "' . $self->{Lit} . '"';
  }
  else {
    return ' ' . $self->{Group}->read( $level + 1 );
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SpeL::Object::Subscript - LaTeX subscript object

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

Represents a LaTeX power

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
