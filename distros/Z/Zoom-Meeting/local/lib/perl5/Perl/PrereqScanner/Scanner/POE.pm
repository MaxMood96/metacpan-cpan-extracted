use strict;
use warnings;

package Perl::PrereqScanner::Scanner::POE 1.100;
# ABSTRACT: scan for POE components

use Moo;
with 'Perl::PrereqScanner::Scanner';

#pod =head1 DESCRIPTION
#pod
#pod This scanner will look for POE modules included with C<use POE>
#pod
#pod   use POE wq(Component::IRC);
#pod
#pod =cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    if ( $node->module eq 'POE' ) {
      my @meat = grep {
           $_->isa('PPI::Token::QuoteLike::Words')
        || $_->isa('PPI::Token::Quote')
      } $node->arguments;

      my @components = map { $self->_q_contents($_) } @meat;
      $req->add_minimum("POE::$_" => 0) for @components;
    }
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::PrereqScanner::Scanner::POE - scan for POE components

=head1 VERSION

version 1.100

=head1 DESCRIPTION

This scanner will look for POE modules included with C<use POE>

  use POE wq(Component::IRC);

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 AUTHORS

=over 4

=item *

Jerome Quelin

=item *

Ricardo Signes <cpan@semiotic.systems>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Jerome Quelin.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
