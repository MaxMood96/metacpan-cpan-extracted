use v5.12.0;
package Pod::Elemental::Transformer::SynMux 0.101001;
# ABSTRACT: apply multiple SynHi transformers to one document in one pass

use Moose;
with 'Pod::Elemental::Transformer::SynHi';

use namespace::autoclean;

#pod =head1 SYNOPSIS
#pod
#pod   my $xform = Pod::Elemental::Transformer::SynMux->new({
#pod     transformers => [ @list_of_SynHi_transformers ],
#pod   });
#pod
#pod   $xform->transform_node( $pod_document );
#pod
#pod =head1 OVERVIEW
#pod
#pod SynMux uses an array of SynHi transformers to perform syntax highlighting
#pod markup in one pass over the input Pod.
#pod
#pod If multiple transformers for the same format name have been given, an exception
#pod will be thrown at object construction time.
#pod
#pod Also, if the C<format_name> attribute for the transformer is set (and it
#pod defaults to set, to C<synmux>) then a single hunk of code may be marked to be
#pod syntax highlighted by multiple highlighters, then concatenated together, for
#pod example:
#pod
#pod   #!synmux
#pod   #!perl
#pod
#pod   print "This code will be highlighted with the #!perl highlighter.";
#pod   #!vim javascript
#pod
#pod   console.log("...and this code by VimHTML javascript syntax.");
#pod
#pod All the shebang lines will be stripped.  Assuming the syntax highlighting
#pod transformers all behave close to the standard behavior, you'll end up with one
#pod code box with multiple styles of highlighting in it, which can be useful for
#pod marking up one document with a few kinds of syntax.
#pod
#pod =cut

use List::MoreUtils qw(natatime);
use MooseX::Types;
use MooseX::Types::Moose qw(Maybe ArrayRef HashRef);
use Pod::Elemental::Types qw(FormatName);

has format_name => (
  is  => 'ro',
  isa => Maybe[ FormatName ],
  default => 'synmux',
);

has transformers => (
  is  => 'ro',
  isa => ArrayRef[ role_type('Pod::Elemental::Transformer::SynHi') ],
  required => 1,
);

sub transform_node {
  my ($self, $node) = @_;

  CHILD: for my $i (0 .. (@{ $node->children } - 1)) {
    my $para = $node->children->[ $i ];

    if (
      defined $self->format_name
      and my $arg = $self->synhi_params_for_para($para)
    ) {
      my $new = $self->build_html_para(@$arg);
      $node->children->[ $i ] = $new;
    } else {
      XFORM: for my $xform (@{ $self->transformers }) {
        next XFORM unless my $arg = $xform->synhi_params_for_para($para);
        my $new = $xform->build_html_para(@$arg);

        $node->children->[ $i ] = $new;
        last XFORM;
      }
    }
  }

  return $node;
}

sub build_html {
  my ($self, $str, $param) = @_;

  my $marker = $param->{marker};

  my (@hunks) = split /^\Q$marker\E(\S+)(?:\h+([^\n]+))?\n/m, $str;
  shift @hunks; # eliminate the leading pre-marker space

  my $html = '';
  my $iter = natatime 3, @hunks;
  while (my ($name, $param_str, $content) = $iter->()) {
    my $xform = $self->_name_registry->{ $name };

    confess "unknown transformation $name in SynMux region" unless $xform;
    my $param = $xform->parse_synhi_param($param_str);
    $html .= $xform->build_html($content, $param);
  }

  return $html;
}

sub parse_synhi_param {
  my ($self, $str) = @_;

  my @opts = split /\s+/, $str;

  $opts[0] //= 'marker:#!';

  confess "illegal SynMux region parameter: $str"
    unless @opts == 1 and $opts[0] =~ /\Amarker:/;

  my (undef, $marker) = split /:/, $opts[0], 2;

  return { marker => $marker };
}

has _name_registry => (
  is  => 'ro',
  isa => HashRef,
  init_arg => undef,
  default  => sub { {} },
);

sub BUILD {
  my ($self) = @_;

  for (@{ $self->transformers }) {
    my ($name) = $_->format_name;
    confess "format name $name already in use by SynMux transformer"
      if defined $self->format_name and $name eq $self->format_name;

    confess "format name $_ used by more than one transformer"
      if $self->_name_registry->{ $name };

    $self->_name_registry->{ $name } = $_
  }
}

#pod =head1 SEE ALSO
#pod
#pod =for :list
#pod * L<Pod::Elemental::Transformer::SynHi>
#pod
#pod =cut

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pod::Elemental::Transformer::SynMux - apply multiple SynHi transformers to one document in one pass

=head1 VERSION

version 0.101001

=head1 SYNOPSIS

  my $xform = Pod::Elemental::Transformer::SynMux->new({
    transformers => [ @list_of_SynHi_transformers ],
  });

  $xform->transform_node( $pod_document );

=head1 OVERVIEW

SynMux uses an array of SynHi transformers to perform syntax highlighting
markup in one pass over the input Pod.

If multiple transformers for the same format name have been given, an exception
will be thrown at object construction time.

Also, if the C<format_name> attribute for the transformer is set (and it
defaults to set, to C<synmux>) then a single hunk of code may be marked to be
syntax highlighted by multiple highlighters, then concatenated together, for
example:

  #!synmux
  #!perl

  print "This code will be highlighted with the #!perl highlighter.";
  #!vim javascript

  console.log("...and this code by VimHTML javascript syntax.");

All the shebang lines will be stripped.  Assuming the syntax highlighting
transformers all behave close to the standard behavior, you'll end up with one
code box with multiple styles of highlighting in it, which can be useful for
marking up one document with a few kinds of syntax.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 SEE ALSO

=over 4

=item *

L<Pod::Elemental::Transformer::SynHi>

=back

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
