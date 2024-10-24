use strict;
use warnings;
package Rubric::Entry::Formatter::HTMLEscape 0.157;
# ABSTRACT: format into HTML by escaping entities

#pod =head1 DESCRIPTION
#pod
#pod This formatter only handles formatting to HTML, and outputs the original
#pod content with HTML-unsafe characters escaped and paragraphs broken.
#pod
#pod This is equivalent to filtering with Template::Filters' C<html> and
#pod C<html_para> filters.
#pod
#pod =cut

use Template::Filters;

#pod =head1 METHODS
#pod
#pod =cut

my ($filter, $html, $para);
{
  my $filters = Template::Filters->new;
  $html = $filters->fetch('html');
  $para = $filters->fetch('html_para');

  $filter = sub {
    $para->( $html->($_[0]) );
  }
}

sub as_html {
  my ($class, $arg) = @_;
  return '' unless $arg->{text};
  return $filter->($arg->{text});
}

sub as_text {
  my ($class, $arg) = @_;
  return '' unless $arg->{text};
  return $html->($arg->{text});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Rubric::Entry::Formatter::HTMLEscape - format into HTML by escaping entities

=head1 VERSION

version 0.157

=head1 DESCRIPTION

This formatter only handles formatting to HTML, and outputs the original
content with HTML-unsafe characters escaped and paragraphs broken.

This is equivalent to filtering with Template::Filters' C<html> and
C<html_para> filters.

=head1 PERL VERSION

This code is effectively abandonware.  Although releases will sometimes be made
to update contact info or to fix packaging flaws, bug reports will mostly be
ignored.  Feature requests are even more likely to be ignored.  (If someone
takes up maintenance of this code, they will presumably remove this notice.)
This means that whatever version of perl is currently required is unlikely to
change -- but also that it might change at any new maintainer's whim.

=head1 METHODS

=head1 AUTHOR

Ricardo SIGNES <rjbs@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
