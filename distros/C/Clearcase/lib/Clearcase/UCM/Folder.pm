
=pod

=head1 NAME Folder.pm

Object oriented interface to UCM Folders

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

Provides access to information about Clearcase Folders.

  my $folder = new Clearcase::UCM::Folder ($name, $pvob);

=head1 DESCRIPTION

This module implements a UCM Folder object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM::Folder;

use strict;
use warnings;

sub new ($$;$$) {
  my ($class, $name, $pvob, $parent, $comment) = @_;

=pod

=head2 new

Construct a new Clearcase Folder object.

Parameters:

=for html <blockquote>

=over

=item folder

Name of folder

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Folder object

=back

=for html </blockquote>

=cut

  $class = bless {
    name   => $name,
    pvob   => $pvob,
    parent => $parent || 'RootFolder',
    },
    $class;    # bless

  $comment = Clearcase::setComment ($comment);

  my ($status, @output) =
    $Clearcase::CC->execute ("mkfolder $comment -in "
      . $class->{parent} . ' '
      . $name . '@'
      . $pvob->tag);

  return if $status;

  ($status, @output) = $class->updateFolderInfo;

  return $status ? undef : $class;
}    # new

sub name () {
  my ($self) = @_;

=pod

=head2 name

Returns the name of the folder

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item folder's name

=back

=for html </blockquote>

=cut

  return $self->{name};
}    # name

sub owner () {
  my ($self) = @_;

=pod

=head2 owner

Returns the owner of the folder

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item folder's owner

=back

=for html </blockquote>

=cut

  return $self->{owner};
}    # owner

sub group () {
  my ($self) = @_;

=pod

=head2 group

Returns the group of the folder

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item folder's group

=back

=for html </blockquote>

=cut

  return $self->{group};
}    # group

sub pvob () {
  my ($self) = @_;

=pod

=head2 pvob

Returns the pvob of the folder

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item folder's pvob

=back

=for html </blockquote>

=cut

  return $self->{pvob};
}    # pvob

sub title () {
  my ($self) = @_;

=pod

=head2 title

Returns the title of the folder

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item folder's title

=back

=for html </blockquote>

=cut

  return $self->{title};
}    # title

sub create ($;$) {
  my ($self, $name, $parentFolder) = @_;

=pod

=head2 create

Creates a new UCM Folder Object

Parameters:

=for html <blockquote>

=over

=item name

UCM Folder name

=item parentFolder

Name of parentFolder (Default: RootFolder)

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

  # Fill in object members
  $self->{parentFolder} = $parentFolder;

  $parentFolder ||= 'RootFolder';

  # Need to create the folder
  return $Clearcase::CC->execute ("mkfolder $self->{comment} -in "
      . $parentFolder . '@'
      . $self->{pvob} . ' '
      . $self->{name});
}    # create

sub remove () {
  my ($self) = @_;

=pod

=head2 remove

Removes UCM Folder

Parameters:

=for html <blockquote>

=over

=item name

UCM Folder name

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $status

Status from cleartool

=item @output

Output from cleartool

=back

=for html </blockquote>

=cut

  return $Clearcase::CC->execute (
    'rmfolder -f ' . $self->{name} . "\@" . $self->{pvob}->tag);
}    # rmfolder

sub updateFolderInfo () {
  my ($self) = @_;

  my ($status, @output) = $Clearcase::CC->execute (
    "lsfolder -long $self->{name}" . '@' . $self->{pvob}->tag);

  return if $status;

  for (@output) {
    if (/owner: (.*)/) {
      $self->{owner} = $1;
    } elsif (/group: (.*)/) {
      $self->{group} = $1;
    } elsif (/title: (.*)/) {
      $self->{title} = $1;

      # TODO: Get containing folders and containing projects
    }    # if
  }    # for

  return $self;
}    # updateFolderInfo

1;

=head1 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=item L<Clearcase::UCM::Baseline|Clearcase::UCM::Baseline>

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
