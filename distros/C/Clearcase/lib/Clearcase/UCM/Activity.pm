
=pod

=head1 NAME Activity.pm

Object oriented interface to UCM Activities

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.10 $

=item Created

Fri May 14 18:16:16 PDT 2010

=item Modified

$Date: 2011/11/15 01:56:40 $

=back

=head1 SYNOPSIS

Provides access to information about Clearcase Activites.

 my $activity = new Clearcase::UCM::Activity ($name, $pvob);
 
 my @changeset = $activity->changeset;
 
 for my $element (@changeset) {
   print "Element name: "    . $element->pname . "\n";
   print "Element verison: " . $element->version . "\n";
 } # for

=head1 DESCRIPTION

This module implements a UCM Activity object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM::Activity;

use strict;
use warnings;

# We should really inherit these from a more generic super class...
sub _processOpts(%) {
  my ($self, %opts) = @_;

  my $opts;

  for (keys %opts) {
    if ($_ eq 'cq' or $_ eq 'cqe' or $_ eq 'force' or $_ eq 'nc') {
      $opts .= "-$_ ";
    } elsif ($_ eq 'c' or $_ eq 'cfile') {
      $opts .= "-$_ $opts{$_}";
    }    # if
  }    # for

  return $opts;
}    # _processOpts

sub new($$) {
  my ($class, $activity, $pvob) = @_;

=pod

=head2 new

Construct a new Clearcase Activity object.

Parameters:

=for html <blockquote>

=over

=item activity name

Name of activity

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Activity object

=back

=for html </blockquote>

=cut

  $class = bless {
    name => $activity,
    pvob => $pvob,
    type => $activity =~ /^(deliver|rebase)./ ? 'integration' : 'regular',
    },
    $class;    # bless

  return $class;
}    # new

sub name() {
  my ($self) = @_;

=pod

=head2 name

Returns the name of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's name

=back

=for html </blockquote>

=cut

  return $self->{name};
}    # name

sub pvob() {
  my ($self) = @_;

=pod

=head2 pvob

Returns the pvob of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's pvob

=back

=for html </blockquote>

=cut

  return $self->{pvob};
}    # pvob

sub type() {
  my ($self) = @_;

=pod

=head2 type

Returns the type of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's type

=back

=for html </blockquote>

=cut

  return $self->{type};
}    # type

sub contrib_acts() {
  my ($self) = @_;

=pod

=head2 contrib_acts

Returns the contributing activities

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Array of contributing activities

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{contrib_acts};

  return $self->{contrib_acts};
}    # crm_record

sub crm_record_id() {
  my ($self) = @_;

=pod

=head2 crm_record_id

Returns the crm_record_id of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's crm_record_id

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{crm_record_id};

  return $self->{crm_record_id};
}    # crm_record_id

sub crm_record_type() {
  my ($self) = @_;

=pod

=head2 crm_record_type

Returns the crm_record_type of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's crm_record_type

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{crm_record_type};

  return $self->{crm_record_type};
}    # crm_record_type

sub crm_state() {
  my ($self) = @_;

=pod

=head2 crm_state

Returns the crm_state of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's crm_state

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{crm_state};

  return $self->{crm_state};
}    # crm_state

sub headline() {
  my ($self) = @_;

=pod

=head2 headline

Returns the headline of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's headline

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{headline};

  return $self->{headline};
}    # headline

sub name_resolver_view() {
  my ($self) = @_;

=pod

=head2 name_resolver_view

Returns the name_resolver_view of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's name_resolver_view

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{name_resolver_view};

  return $self->{name_resolver_view};
}    # name_resolver_view

sub stream() {
  my ($self) = @_;

=pod

=head2 stream

Returns the stream of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item activity's stream

=back

=for html </blockquote>

=cut

  $self->updateActivityInfo () unless $self->{stream};

  return $self->{stream};
}    # stream

sub changeset(;$) {
  my ($self, $recalc) = @_;

=pod

=head2 changeset

Returns the changeset of the activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item An array containing Clearcase::Element objects.

=back

=for html </blockquote>

=cut

  if ($self->{changeset}) {
    return $self->{changeset} unless ($recalc);
  }    # if

  my $pvob = Clearcase::vobtag $self->{pvob};

  my $cmd = "lsact -fmt \"%[versions]CQp\" $self->{name}\@$pvob";

  my ($status, @output) = $Clearcase::CC->execute ($cmd);

  return ($status, @output)
    if $status;

  # Need to split up change set. It's presented to us as quoted and space
  # separated however the change set elements themselves can have spaces in
  # them! e.g.:
  #
  #   "/vob/foo/file name with spaces@@/main/1", "/vob/foo/file name2@@/main/2"
  #
  # So we'll split on '", ""'! Note that this will leave us with the first
  # element with a leading '"' and the last element with a trailing '"' which
  # we will have to handle.
  #
  # Additionally we will call collapseOverExtendedViewPathname to normalize
  # the over extended pathnames to element hashes.
  my (@changeset);

  @output = split /\", \"/, $output[0]
    if $output[0];

  for (@output) {

    # Skip any cleartool warnings. We are getting warnings of the form:
    # "A version in the change set of activity "63332.4" is currently
    # unavailable". Probably some sort of subtle corruption that we can ignore.
    # (It should be fixed but we aren't going to be doing that here!)
    next if /cleartool: Warning/;

    # Strip any remaining '"'s
    s/^\"//;
    s/\"$//;

    my %element = Clearcase::Element::collapseOverExtendedVersionPathname $_;
    my $element = Clearcase::Element->new ($element{name});

    # Sometimes $element{name} refers to a long path name we can't easily see
    # in our current view. In such cases the above Clearcase::Element->new will
    # return us an element where the version is missing. Since we already have
    # the version information we will replace it here.
    #
    # The following may look odd since we use similar names against different
    # Perl variables. $element->{version} means look into the $element object
    # returned from new above at the member version. $element{version} says
    # refer to the %element hash defined above for the version key. And finally
    # $element->version says call the method version of the element object.
    # So we are saying, if the version member of the element object is not
    # defined (i.e. $element->version) then set it (i.e. $element->{version})
    # by using the value of the hash %element with the key version.
    $element->{version} = $element{version}
      unless $element->version;

    # Additionally we will set into the $element object the extended name. This
    # is the long pathname that we need to use from our current context to be
    # able to access the element.
    #$element->setExtendedName($_);

    push @changeset, $element;
  }    # for

  $self->{changeset} = \@changeset;

  return @changeset;
}    # changeset

sub exists() {
  my ($self) = @_;

  my ($status, @output) = $Clearcase::CC->execute (
    'lsactivity ' . $self->{name} . '@' . $self->pvob->tag);

  return !$status;
}    # exists

sub create($$$;$) {
  my ($self, $stream, $headline, $opts) = @_;

=pod

=head2 create

Creates a new UCM Activity

Parameters:

=for html <blockquote>

=over

=item UCM Stream(required)

UCM stream this activities is to be created on

=item PVOB (Required)

Project Vob

=item headline

Headline to associate with this activity

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

  if ($self->exists) {
    $self->updateActivityInfo;

    return (0, ());
  }    # if

  # Fill in opts
  $opts ||= '';

  if ($headline) {
    $self->{headline} = $headline;

    $opts .= " -headline '$headline'";
  }    # if

  $self->{stream} = Clearcase::UCM::Stream->new ($stream, $self->{pvob});

  return $Clearcase::CC->execute ("mkactivity $opts -in "
      . $stream->{name} . '@'
      . $self->pvob->{tag} . ' '
      . $self->{name} . '@'
      . $self->pvob->{tag});
}    # create

sub remove() {
  my ($self) = @_;

=pod

=head2 remove

Removes UCM Activity

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
    'rmactivity -f ' . $self->{name} . "\@" . $self->{pvob}->name);
}    # remove

sub attributes(;%) {
  my ($self, %newAttribs) = @_;

=pod

=head2 attributes

Returns a hash of the attributes associated with an activity

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %attributes

Hash of attributes for this activity

=back

=for html </blockquote>

=cut

  return $self->Clearcase::attributes ('activity',
    "$self->{name}\@" . $self->{pvob}->name, %newAttribs,);
}    # attributes

=pod

=head2 updateActivityInfo()

Update the activity info

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

=pod

=head2 updateActivityInfo()

Update the activity info

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub updateActivityInfo() {
  my ($self) = @_;

  # Get all information that can be gotten using -fmt
  my $fmt .= '%[crm_record_id]p==';
  $fmt    .= '%[crm_record_type]p==';
  $fmt    .= '%[crm_state]p==';
  $fmt    .= '%[headline]p==';
  $fmt    .= '%[name_resolver_view]p==';
  $fmt    .= '%[stream]Xp==';
  $fmt    .= '%[view]p';

  if ($self->type eq 'integration') {
    $fmt = '%[contrib_acts]CXp==';
  }    # if

  $Clearcase::CC->execute (
    "lsactivity -fmt \"$fmt\" $self->{name}@" . $self->{pvob}->name);

  # Assuming this activity is an empty shell of an object that the user may
  # possibly use the create method on, return our blessings...
  return if $Clearcase::CC->status;

  # We need to make sure that fields are filled in or empty because we are using
  # undef as an indication that we have not called updateActivityInfo yet.
  my @fields = split '==', $Clearcase::CC->output;

  $self->{crm_record_id}      = $fields[0];
  $self->{crm_record_type}    = $fields[1];
  $self->{crm_state}          = $fields[2];
  $self->{headline}           = $fields[3];
  $self->{name_resolver_view} = $fields[4];
  $self->{stream}             = $fields[5];
  $self->{view}               = $fields[6];

  $self->{contrib_acts} = ();

  if ($self->type eq 'integration') {
    for (split ', ', $fields[7]) {
      push @{$self->{contrib_acts}}, Clearcase::UCM::Activity->new ($_);
    }    # for
  }    # if

  return;
}    # updateActivityInfo

1;

=head1 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

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
