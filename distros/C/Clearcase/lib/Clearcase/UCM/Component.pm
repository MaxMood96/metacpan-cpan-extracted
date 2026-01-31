
=pod

=head1 NAME Component.pm

Object oriented interface to UCM Component

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

Provides access to information about Clearcase Components.

  my $stream = new Clearcase::UCM::Component($name, $pvob);

=head1 DESCRIPTION

This module implements a UCM Component object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM::Component;

use strict;
use warnings;

use Carp;

sub new ($$) {
  my ($class, $name, $pvob) = @_;

=pod

=head2 new

Construct a new Clearcase Component object.

Parameters:

=for html <blockquote>

=over

=item name

Name of Component

=item pvob

Associated pvob

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Component object

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

Returns the name of the component

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item name

=back

=for html </blockquote>

=cut

  return $self->{name};
}    # name

sub pvob () {
  my ($self) = @_;

=pod

=head2 pvob

Returns the pvob of the component

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item pvob

=back

=for html </blockquote>

=cut

  return $self->{pvob};
}    # pvob

sub create (;$$) {
  my ($self, $root, $comment) = @_;

=pod

=head2 create

Creates a new UCM Component Object

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

  return (0, ()) if $self->exists;

  $comment = Clearcase::setComment $comment;

  my $rootOpt;

  if ($root) {
    if (-d $root) {
      $self->{root} = $root;

      $rootOpt = "-root $root";
    } else {
      carp "Root $root not found";
    }    # if
  } else {
    $self->{root} = undef;

    $rootOpt = '-nroot';
  }    # if

  return $Clearcase::CC->execute (
    "mkcomp $comment $rootOpt " . $self->{name} . '@' . $self->{pvob}->tag);
}    # create

sub remove () {
  my ($self) = @_;

=pod

=head2 remove

Removes UCM Component

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
    'rmcomp -f ' . $self->name . '@' . $self->pvob->tag);
}    # remove

sub exists() {
  my ($self) = @_;

=pod

=head3 exists

Returns true if the component exists - false otherwise.

Parameters:

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
    'lscomp ' . $self->{name} . '@' . $self->{pvob}->name);

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
