package Pod::Weaver::Section::Collect 4.019;
# ABSTRACT: a section that gathers up specific commands

use Moose;
with 'Pod::Weaver::Role::Section',
     'Pod::Weaver::Role::Transformer';

# BEGIN BOILERPLATE
use v5.20.0;
use warnings;
use utf8;
no feature 'switch';
use experimental qw(postderef postderef_qq); # This experiment gets mainlined.
# END BOILERPLATE

#pod =head1 OVERVIEW
#pod
#pod Given the configuration:
#pod
#pod   [Collect / METHODS]
#pod   command = method
#pod
#pod This plugin will start off by gathering and nesting any C<=method> commands
#pod found in the C<pod_document>.  Those commands, along with their nestable
#pod content, will be collected under a C<=head1 METHODS> header and placed in the
#pod correct location in the output stream.  Their order will be preserved as it was
#pod in the source document.
#pod
#pod =cut

use Pod::Elemental::Element::Pod5::Region;
use Pod::Elemental::Selectors -all;
use List::Util 1.33 'any';

#pod =attr command
#pod
#pod The command that will be collected (e.g. C<attr> or C<method>).
#pod (required)
#pod
#pod =attr new_command
#pod
#pod The command to be used in the output instead of the collected command.
#pod (default: C<head2>)
#pod
#pod =attr header_command
#pod
#pod The section command for the section to be added.
#pod (default: C<head1>)
#pod
#pod =attr header
#pod
#pod The title of the section to be added.
#pod (default: the plugin name)
#pod
#pod =cut

has command => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has new_command => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
  default  => 'head2',
);

has header_command => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
  default  => 'head1',
);

has header => (
  is  => 'ro',
  isa => 'Str',
  lazy     => 1,
  required => 1,
  default  => sub { $_[0]->plugin_name },
);

use Pod::Elemental::Transformer::Gatherer;
use Pod::Elemental::Transformer::Nester;

has __used_container => (is => 'rw');

sub transform_document {
  my ($self, $document) = @_;

  my $command = $self->command;
  my $selector = s_command($command);

  my $children = $document->children;
  unless (any { $selector->($_) } @$children) {
    $self->log_debug("no $command commands in pod to collect");
    return;
  }

  $self->log_debug("transforming $command commands into standard pod");

  my $nester = Pod::Elemental::Transformer::Nester->new({
     top_selector      => $selector,
     content_selectors => [
       s_command([ qw(head3 head4 over item back) ]),
       s_flat,
     ],
  });

  # try and find array position of suitable host
  my ( $container_id ) = grep {
    my $c = $children->[$_];
    $c->isa("Pod::Elemental::Element::Nested")
      and $c->command eq $self->header_command and $c->content eq $self->header;
  } 0 .. $#$children;

  my $container = $container_id
    ? splice @$children, $container_id, 1 # excise host
    : Pod::Elemental::Element::Nested->new({ # synthesize new host
        command => $self->header_command,
        content => $self->header,
      });

  $self->__used_container($container);

  my $gatherer = Pod::Elemental::Transformer::Gatherer->new({
    gather_selector => $selector,
    container       => $container,
  });

  $nester->transform_node($document);
  my @children = $container->children->@*; # rescue children
  $gatherer->transform_node($document); # insert host at position of first adopt-child and inject it with adopt-children
  foreach my $child ($container->children->@*) {
    $child->command( $self->new_command ) if $child->command eq $command;
  }
  unshift $container->children->@*, @children; # give original children back to host
}

sub weave_section {
  my ($self, $document, $input) = @_;

  return unless $self->__used_container;

  my $in_node = $input->{pod_document}->children;

  my @found = grep {
    my ($i, $para) = ($_, $in_node->[$_]);
    ($para == $self->__used_container)
      && $self->__used_container->children->@*;
  } (0 .. $#$in_node);

  push $document->children->@*, map { splice @$in_node, $_, 1 } reverse @found;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pod::Weaver::Section::Collect - a section that gathers up specific commands

=head1 VERSION

version 4.019

=head1 OVERVIEW

Given the configuration:

  [Collect / METHODS]
  command = method

This plugin will start off by gathering and nesting any C<=method> commands
found in the C<pod_document>.  Those commands, along with their nestable
content, will be collected under a C<=head1 METHODS> header and placed in the
correct location in the output stream.  Their order will be preserved as it was
in the source document.

=head1 PERL VERSION

This module should work on any version of perl still receiving updates from
the Perl 5 Porters.  This means it should work on any version of perl released
in the last two to three years.  (That is, if the most recently released
version is v5.40, then this module should work on both v5.40 and v5.38.)

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 ATTRIBUTES

=head2 command

The command that will be collected (e.g. C<attr> or C<method>).
(required)

=head2 new_command

The command to be used in the output instead of the collected command.
(default: C<head2>)

=head2 header_command

The section command for the section to be added.
(default: C<head1>)

=head2 header

The title of the section to be added.
(default: the plugin name)

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
