
=pod

=head1 NAME Stream.pm

Object oriented interface to UCM Streams

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.8 $

=item Created

Fri May 14 18:16:16 PDT 2010

=item Modified

$Date: 2011/11/15 02:00:58 $

=back

=head1 SYNOPSIS

Provides access to information about Clearcase Streams.

  my $stream = new Clearcase::UCM::Stream ($name, $pvob);

=head1 DESCRIPTION

This module implements a UCM Stream object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM::Stream;

use strict;
use warnings;

sub new ($$) {
  my ($class, $name, $pvob) = @_;

=pod

=head2 new

Construct a new Clearcase Stream object.

Parameters:

=for html <blockquote>

=over

=item name

Name of stream

=item pvob

Associated pvob

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Stream object

=back

=for html </blockquote>

=cut

  $class = bless {
    name => $name,
    pvob => $pvob,
    },
    $class;    # bless

  return $class;
}    # new

sub name () {
  my ($self) = @_;

=pod

=head2 name

Returns the name of the stream

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item stream's name

=back

=for html </blockquote>

=cut

  return $self->{name};
}    # name

sub pvob () {
  my ($self) = @_;

=pod

=head2 pvob

Returns the pvob of the stream

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item stream's pvob

=back

=for html </blockquote>

=cut

  return $self->{pvob};
}    # pvob

sub create ($;$) {
  my ($self, $project, $opts) = @_;

=pod

=head2 create

Creates a new UCM Stream Object

Parameters:

=for html <blockquote>

=over

=item project

Project that this stream will be created in

=item opts

Options: Additional options to use (e.g. -baseline/-readonly)

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Ouput from cleartool

=back

=for html </blockquote>

=cut

  return (0, ()) if $self->exists;

  $opts ||= '';

  $self->{readonly} = $opts =~ /-readonly/;

  return $Clearcase::CC->execute ("mkstream $opts -in "
      . $project->name . '@'
      . $self->{pvob}->tag . ' '
      . $self->name . '@'
      . $self->{pvob}->tag);
}    # create

sub remove () {
  my ($self) = @_;

=pod

=head2 remove

Removes UCM Stream

Parameters:

=for html <blockquote>

=over

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Ouput from cleartool

=back

=for html </blockquote>

=cut

  return $Clearcase::CC->execute (
    'rmstream -f ' . $self->{name} . '@' . $self->{pvob}->name);
}    # rmStream

sub rebase($;$) {
  my ($self, $opts) = @_;

=pod

=head2 rebase

Rebases a UCM Stream

Parameters:

=for html <blockquote>

=over

=item baseline

Baseline to rebase to

=item opts

Any additional opts

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Ouput from cleartool

=back

=for html </blockquote>

=cut

  $opts ||= '';

  $opts .= ' -stream ' . $self->name . '@' . $self->{pvob}->name;

  return $Clearcase::CC->execute ("rebase $opts");
}    # rebase

sub recommend($) {
  my ($self, $baseline) = @_;

=pod

=head2 recommend

Recommends a baseline in a UCM Stream

Parameters:

=for html <blockquote>

=over

=item baseline

Baseline to recommend

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Ouput from cleartool

=back

=for html </blockquote>

=cut

  return $Clearcase::CC->execute ("chstream -recommended $baseline "
      . $self->name . '@'
      . $self->{pvob}->tag);
}    # recommend

sub nrecommended() {
  my ($self) = @_;

=pod

=head2 nrecommend

Changes stream to not have a recommended baseline

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Ouput from cleartool

=back

=for html </blockquote>

=cut

  return $Clearcase::CC->execute (
    'chstream -nrecommended ' . $self->name . '@' . $self->{pvob}->tag);
}    # nrecommended

sub baselines () {
  my ($self) = @_;

=pod

=head2 baselines

Returns baseline objects associated with the stream

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item @baselines

An array of baseline objects for this stream

=back

=for html </blockquote>

=cut

  my $cmd = "lsbl -short -stream $self->{name}\@$self->{pvob}";

  $Clearcase::CC->execute ($cmd);

  return if $Clearcase::CC->status;

  my @baselines;

  for ($Clearcase::CC->output) {
    my $baseline = Clearcase::UCM::Baseline->new ($_, $self->{pvob});

    push @baselines, $baseline;
  }    # for

  return @baselines;
}    # baselines

sub exists() {
  my ($self) = @_;

=pod

=head3 exists

Return true if the stream exists - false otherwise

Paramters:

=for html <blockquote>

=over 

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item boolean

=back

=for html </blockquote>

=cut

  my ($status, @output) = $Clearcase::CC->execute (
    'lsstream ' . $self->{name} . '@' . $self->{pvob}->name);

  return !$status;
}    # exists

1;

=head1 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=item L<Clearcase::UCM::Baseline|Clearcase::UCM::Baseline>

=item L<Clearcase::UCM::Project|Clearcase::UCM::Project>

=back

=head1 INCOMPATABILITIES

None

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Andrew@DeFaria.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.38.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
