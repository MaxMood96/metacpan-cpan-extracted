package Pod::Weaver::Plugin::EnsurePod5 4.020;
# ABSTRACT: ensure that the Pod5 translator has been run on this document

use Moose;
with 'Pod::Weaver::Role::Preparer';

# BEGIN BOILERPLATE
use v5.20.0;
use warnings;
use utf8;
no feature 'switch';
use experimental qw(postderef postderef_qq); # This experiment gets mainlined.
# END BOILERPLATE

use namespace::autoclean;

use Pod::Elemental::Transformer::Pod5;

#pod =head1 OVERVIEW
#pod
#pod This plugin is very, very simple:  it runs the Pod5 transformer on the input
#pod document and removes any leftover whitespace-only Nonpod elements.  If
#pod non-whitespace-only Nonpod elements are found, an exception is raised.
#pod
#pod =cut

sub _strip_nonpod {
  my ($self, $node) = @_;

  # XXX: This is really stupid. -- rjbs, 2009-10-24

  foreach my $i (reverse 0 .. $node->children->$#*) {
    my $para = $node->children->[$i];

    if ($para->isa('Pod::Elemental::Element::Pod5::Nonpod')) {
      if ($para->content !~ /\S/) {
        splice $node->children->@*, $i, 1
      } else {
        confess "can't cope with a Nonpod element with non-whitespace content";
      }
    } elsif ($para->does('Pod::Elemental::Node')) {
      $self->_strip_nonpod($para);
    }
  }
}

sub prepare_input {
  my ($self, $input) = @_;
  my $pod_document = $input->{pod_document};

  Pod::Elemental::Transformer::Pod5->new->transform_node($pod_document);

  $self->_strip_nonpod($pod_document);

  return;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pod::Weaver::Plugin::EnsurePod5 - ensure that the Pod5 translator has been run on this document

=head1 VERSION

version 4.020

=head1 OVERVIEW

This plugin is very, very simple:  it runs the Pod5 transformer on the input
document and removes any leftover whitespace-only Nonpod elements.  If
non-whitespace-only Nonpod elements are found, an exception is raised.

=head1 PERL VERSION

This module should work on any version of perl still receiving updates from
the Perl 5 Porters.  This means it should work on any version of perl
released in the last two to three years.  (That is, if the most recently
released version is v5.40, then this module should work on both v5.40 and
v5.38.)

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to
lower the minimum required perl.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
