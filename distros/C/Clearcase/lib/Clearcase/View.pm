
=pod

=head1 NAME View.pm

Object oriented interface to a Clearcase View

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.18 $

=item Created

Thu Dec 29 12:07:59 PST 2005

=item Modified

$Date: 2011/11/16 19:46:13 $

=back

=head1 SYNOPSIS

Provides access to information about a Clearcase View. Note that some
information about a view is not populated into the view object at
object instantiation. This is because members such as labels can be
very long and time consuming to acquire. When the caller request such
fields they are expanded.

 # Create View object
 my $view = new Clearcase::View (tag => 'test');

 # Access member variables...
 print "View:\t\t \t"         . $view->tag . "\n";
 print "Accessed by:\t\t"     . $view->accessed_by . "\n";
 print "Accessed date:\t\t"   . $view->accessed_date . "\n";
 print "Access path:\t\t"     . $view->access_path . "\n";
 print "Active:\t\t\t"        . $view->active . "\n";

 print "Additional groups:\t";

 for ($view->additional_groups) {
   print "$_ ";
 } # for

 print "\n";

 print "Created by:\t\t"      . $view->created_by . "\n";
 print "Created date:\t\t"    . $view->created_date . "\n";
 print "CS updated by:\t\t"   . $view->cs_updated_by . "\n";
 print "CS updated date:\t"   . $view->cs_updated_date . "\n";
 print "Global path:\t\t"     . $view->gpath . "\n";
 print "Group:\t\t\t"         . $view->group . "\n";
 print "Group mode:\t\t"      . $view->group_mode . "\n";
 print "Host:\t\t\t"          . $view->host . "\n";
 print "Mode:\t\t\t"          . $view->mode . "\n";
 print "Modified by:\t\t"     . $view->modified_by . "\n";
 print "Modified date:\t\t"   . $view->modified_date . "\n";
 print "Other mode:\t\t"      . $view->other_mode . "\n";
 print "Owner:\t\t\t"         . $view->owner . "\n";
 print "Owner mode:\t\t"      . $view->owner_mode . "\n";
 print "Properties:\t\t"      . $view->properties . "\n";
 print "Region:\t\t\t"        . $view->region . "\n";
 print "Server host:\t\t"     . $view->shost . "\n";
 print "Text mode:\t\t"       . $view->text_mode . "\n";
 print "UUID:\t\t\t"          . $view->uuid . "\n";

 print "Type:\t\t\t";

 if ($view->snapshot) {
   print 'snapshot';
 } else {
   print 'dynamic';
 } # if

 if ($view->ucm) {
   print ',ucm';
 } # if

 print "\n";

 # View manipulation
 my $new_view = new Clearcase::View ($ENV{USER} . '_testview');

 $new_view->create;

 # Start new view
 $new_view->start;

 # Set to view
 $new_view->set;

 # Stop view
 $new_view->stop;

 # Stop view server process
 $new_view->kill;

 # Remove view
 if ($new_view->exists) {
   $new_view->remove;
 } # if

=head1 DESCRIPTION

This module implements an object oriented interface to a Clearcase
view.

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::View;

use strict;
use warnings;

use Clearcase;

sub new($;$) {
  my ($class, $tag, $region) = @_;

=pod

=head2 new (tag)

Construct a new Clearcase View object. Note that not all members are
initially populated because doing so would be time consuming. Such
member variables will be expanded when accessed.

Parameters:

=for html <blockquote>

=over

=item tag

View tag to be instantiated. You can use either an object oriented call
(i.e. my $view = new Clearcase::View (tag => 'my_new_view')) or the
normal call (i.e. my $vob = new Clearcase::View ('my_new_view')). You
can also instantiate a new view by supplying a tag and then later
calling the create method.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase View object

=back

=for html </blockquote>

=cut

  $region ||= $Clearcase::CC->region;

  my $self = bless {
    tag    => $tag,
    region => $region
  }, $class;

  $self->updateViewInfo;

  return $self;
}    # new

sub accessed_by() {
  my ($self) = @_;

=pod

=head2 accessed_by

Returns the user name of the last user to access the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item user name

=back

=for html </blockquote>

=cut

  return $self->{accessed_by};
}    # accessed_by

sub accessed_date() {
  my ($self) = @_;

=pod

=head2 accessed_date

Returns the date the view was last accessed.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item access date

=back

=for html </blockquote>

=cut

  return $self->{accessed_date};
}    # accessed_date

sub access_path() {
  my ($self) = @_;

=pod

=head2 access_path

Returns the access path of the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item access path

=back

=for html </blockquote>

=cut

  return $self->{access_path};
}    # access_path

sub active() {
  my ($self) = @_;

=pod

=head2 active

Returns true if the view is active

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

  return $self->{active};
}    # active

sub additional_groups() {
  my ($self) = @_;

=pod

=head2 additional_groups

Returns the additional groups that have permission to access this
view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item An array of additional groups

=back

=for html </blockquote>

=cut

  if ($self->{additional_groups}) {
    return @{$self->{additional_groups}};
  } else {
    return ();
  }    # if
}    # additional_groups

sub created_by() {
  my ($self) = @_;

=pod

=head2 created_by

Returns the user name who created the view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item user name

=back

=for html </blockquote>

=cut

  return $self->{created_by};
}    # created_by

sub created_date() {
  my ($self) = @_;

=pod

=head2 created_date

Returns the date the view was created.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item date

=back

=for html </blockquote>

=cut

  return $self->{created_date};
}    # created_date

sub cs_updated_by() {
  my ($self) = @_;

=pod

=head2 cs_updated_date

Returns the user name of the last user to access the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item date

=back

=for html </blockquote>

=cut

  return $self->{cs_updated_by};
}    # cs_updated_by

sub cs_updated_date() {
  my ($self) = @_;

=pod

=head2 dynamic

Returns the date the config spec for this view was updated.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item date

=back

=for html </blockquote>

=cut

  return $self->{cs_updated_date};
}    # cs_updated_date

sub dynamic() {
  my ($self) = @_;

=pod

=head2 dynamic

Returns true if the view is a dynamic view - false otherwise.

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

  return unless $self->{type};
  return $self->type eq 'dynamic';
}    # dynamic

sub gpath() {
  my ($self) = @_;

=pod

=head2 gpath

Returns the global path to the view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item global path

=back

=for html </blockquote>

=cut

  return $self->{gpath};
}    # gpath

sub group() {
  my ($self) = @_;

=pod

=head2 group

Returns the group of the user who created the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item group name

=back

=for html </blockquote>

=cut

  return $self->{group};
}    # group

sub group_mode() {
  my ($self) = @_;

=pod

=head2 group_mode

Returns the group mode of the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item A string representing the group mode

=back

=for html </blockquote>

=cut

  return $self->{group_mode};
}    # group_mode

sub host() {
  my ($self) = @_;

=pod

=head2 host

Returns the host that the view resides on

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item host

=back

=for html </blockquote>

=cut

  return $self->{host};
}    # host

sub mode() {
  my ($self) = @_;

=pod

=head2 mode

Returns the numeric mode representing the view's access mode

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item numeric mode

=back

=for html </blockquote>

=cut

  return $self->{mode};
}    # mode

sub modified_by() {
  my ($self) = @_;

=pod

=head2 modified_by

Returns the user name of the last user to modify the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item user name

=back

=for html </blockquote>

=cut

  return $self->{modified_by};
}    # modified_by

sub modified_date() {
  my ($self) = @_;

=pod

=head2 modified_date

Returns the date the view was last modified.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item date

=back

=for html </blockquote>

=cut

  return $self->{modified_date};
}    # modified_date

sub other_mode() {
  my ($self) = @_;

=pod

=head2 other_mode

Returns the mode for other for the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item A string repesenting the other mode

=back

=for html </blockquote>

=cut

  return $self->{other_mode};
}    # other_mode

sub owner() {
  my ($self) = @_;

=pod

=head2 owner

Returns the user name of the owner of the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item user name

=back

=for html </blockquote>

=cut

  return $self->{owner};
}    # owner

sub owner_mode() {
  my ($self) = @_;

=pod

=head2 owner_mode

Returns the mode for the owner for the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item A string repesenting the other mode

=back

=for html </blockquote>

=cut

  return $self->{owner_mode};
}    # owner_mode

sub properties() {
  my ($self) = @_;

=pod

=head2 properties

Returns the properties of the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item properties

=back

=for html </blockquote>

=cut

  return $self->{properties};
}    # properties

sub region() {
  my ($self) = @_;

=pod

=head2 region

Returns the region of the view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item region

=back

=for html </blockquote>

=cut

  return $self->{region};
}    # region

sub shost() {
  my ($self) = @_;

=pod

=head2 shost

Returns the server host of the view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item server host

=back

=for html </blockquote>

=cut

  return $self->{shost};
}    # shost

sub snapshot() {
  my ($self) = @_;

=pod

=head2 snapshot

Returns true if the view is a snapshot view - false otherwise.

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

  return unless $self->{type};
  return $self->type eq 'snapshot';
}    # snapshot

sub webview() {
  my ($self) = @_;

=pod

=head2 webview

Returns true if the view is a webview - false otherwise.

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

  return unless $self->{type};
  return $self->{type} eq 'webview';
}    # webview

sub tag() {
  my ($self) = @_;

=pod

=head1 tag

Returns the tag for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item tag

=back

=for html </blockquote>

=cut

  return $self->{tag};
}    # tag

sub text_mode() {
  my ($self) = @_;

=pod

=head2 text_mode

Returns the text_mode of the view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item text mode

=back

=for html </blockquote>

=cut

  return $self->{text_mode};
}    # tag

sub type() {
  my ($self) = @_;

=pod

=head2 type

Returns the type of the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item type

=back

=for html </blockquote>

=cut

  return $self->{type};
}    # type

sub ucm() {
  my ($self) = @_;

=pod

=head2 ucm

Returns true if the view is a UCM view.

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

  return $self->{ucm};
}    # ucm

sub uuid() {
  my ($self) = @_;

=pod

=head2 uuid

Returns the uuid for the view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item uuid

=back

=for html </blockquote>

=cut

  return $self->{uuid};
}    # uuid

sub exists() {
  my ($self) = @_;

=pod

=head3 exists

Returns true if the view exists - false otherwise.

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

  my ($status, @output) =
    $Clearcase::CC->execute ("lsview -region $self->{region} $self->{tag}");

  return !$status;
}    # exists

sub create(;$$$) {
  my ($self, $host, $vws, $region) = @_;

=pod

=head2 create

Creates a view

Parameters:

=for html <blockquote>

=over

=item host

Host to create the view on. Default is to use -stgloc -auto.

=item vws

View working storage directory to use. Default is to use -stgloc -auto.

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

  $region ||= $Clearcase::CC->region;

  if ($self->exists) {
    $self->updateViewInfo;

    return (0, ());
  }    # if

  my ($status, @output);

  if ($host && $vws) {
    ($status, @output) =
      $Clearcase::CC->execute ("mkview -tag $self->{tag} -region $region "
        . "-host $host -hpath $vws -gpath $vws $vws");
  } else {

    # Note this requires that -stgloc's work and that using -auto is not a
    # problem.
    ($status, @output) =
      $Clearcase::CC->execute ("mkview -tag $self->{tag} -stgloc -auto");
  }    # if

  $self->updateViewInfo;

  return ($status, @output);
}    # create

sub createUCM($$) {
  my ($self, $stream, $pvob, $region) = @_;

=pod

=head2 createUCM

Create a UCM view

Parameters:

=for html <blockquote>

=over

=item streamName

Name of stream to attach new view to

=item pvob

Name of project vob

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item status

Integer status

=item output

Array of output

=back

=for html </blockquote>

=cut

  $region ||= $Clearcase::CC->region;

  return (0, ())
    if $self->exists;

  # Update object members
  $self->{stream} = $stream;
  $self->{pvob}   = $pvob;

  # Need to create the view
  my ($status, @output) =
    $Clearcase::CC->execute ("mkview -tag $self->{tag} -stream "
      . "$self->{stream}\@$self->{pvob} -stgloc -auto");

  return ($status, @output)
    if $status;

  $self->updateViewInfo;

  return ($status, @output);
}    # createUCM

sub remove() {
  my ($self) = @_;

=pod

=head3 remove

Removes the view.

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

  return (0, ())
    unless $self->exists;

  my ($status, @output);

  if ($self->dynamic) {
    ($status, @output) =
      $Clearcase::CC->execute ("rmview -force -tag $self->{tag}");
  } else {
    die 'Removal of snapshot views not implemented yet';

    #($status, @output) = $Clearcase::CC->execute(
    #  "rmview -force $self->{snapshot_view_pname}"
    #);
  }    # if

  return ($status, @output);
}    # remove

sub start() {
  my ($self) = @_;

=pod

=head2 start

Starts the view.

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

  return $Clearcase::CC->execute ("startview $self->{tag}");
}    # start

sub stop() {
  my ($self) = @_;

=pod

=head2 stop

Stops the view.

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

  return $Clearcase::CC->execute ("endview $self->{tag}");
}    # stop

sub kill() {
  my ($self) = @_;

=pod

=head2 kill

Stops the view at the view_server process if nobody else is accessing the view.

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

  return $Clearcase::CC->execute ("endview -server $self->{tag}");
}    # kill

sub set() {
  my ($self) = @_;

=pod

=head3 set

Starts the view then changes directory the to view's root.

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

  my ($status, @output) = $self->start;

  chdir "$Clearcase::VIEWTAG_PREFIX/$self->{tag}";

  return ($status, @output);
}    # set

=pod

=head2 updateViewInfo ($view)

Updates the view info from cleartool lsview

Parameters:

=for html <blockquote>

=over

=item $view

The view tag to update info for

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

=head2 updateViewInfo ($view)

Updates the view info from cleartool lsview

Parameters:

=for html <blockquote>

=over

=item $view

The view tag to update info for

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub updateViewInfo($$) {
  my ($self) = @_;

  my $region_opt = $self->{region} ? "-region $self->{region}" : "";

  my ($status, @output) = $Clearcase::CC->execute (
    "lsview $region_opt -long -properties -full $self->{tag}");

  return if $status;

  # Assuming this view is an empty shell of an object that the user may possibly
  # use the create method on, return our blessings...

  # No longer assume that. Could equally be the case where the view server
  # failed to respond. Carry on then...return if $status != 0;

  # Defaults
  $self->{type}              = 'dynamic';
  $self->{ucm}               = 0;
  $self->{additional_groups} = '';

  for (@output) {
    if (/Global path: (.*)/) {
      $self->{gpath} = $1;
    } elsif (/Server host: (.*)/) {
      $self->{shost} = $1;
    } elsif (/Region: (.*)/) {
      $self->{region} = $1;
    } elsif (/Active: (.*)/) {
      $self->{active} = ($1 eq 'YES') ? 1 : 0;
    } elsif (/View uuid: (.*)/) {
      $self->{uuid} = $1;
    } elsif (/View on host: (.*)/) {
      $self->{host} = $1;
    } elsif (/View server access path: (.*)/) {
      $self->{access_path} = $1;
    } elsif (/View attributes: (.*)/) {
      my $view_attributes = $1;
      $self->{type} =
          $view_attributes =~ /webview/  ? 'webview'
        : $view_attributes =~ /snapshot/ ? 'snapshot'
        :                                  'dynamic';
      $self->{ucm} =
        $view_attributes =~ /ucmview/
        ? 1
        : 0;
    } elsif (/Created (\S+) by (.+)/) {
      $self->{created_date} = $1;
      $self->{created_by}   = $2;
    } elsif (/Last modified (\S+) by (.+)/) {
      $self->{modified_date} = $1;
      $self->{modified_by}   = $2;
    } elsif (/Last accessed (\S+) by (.+)/) {
      $self->{accessed_date} = $1;
      $self->{accessed_by}   = $2;
    } elsif (/Last config spec update (\S+) by (.+)/) {
      $self->{cs_updated_date} = $1;
      $self->{cs_updated_by}   = $2;
    } elsif (/Text mode: (\S+)/) {
      $self->{text_mode} = $1;
    } elsif (/Properties: (.*)/) {
      $self->{properties} = $1;
    } elsif (/View owner: (\S+)$/) {

      # It is possible that there may be problems enumerating
      # -properties and -full when listing views due to servers
      # no longer being available. Still the "View owner" line
      # denotes the view's owner.
      $self->{owner}      = $1;
      $self->{owner_mode} = '';
    } elsif (/Owner: (\S+)\s+: (\S+)/) {
      $self->{owner}      = $1;
      $self->{owner_mode} = $2;
    } elsif (/Group: (.+)\s+:\s+(\S+)\s+/) {
      $self->{group}      = $1;
      $self->{group_mode} = $2;
    } elsif (/Other:\s+: (\S+)/) {
      $self->{other_mode} = $1;
    } elsif (/Additional groups: (.*)/) {
      my @additional_groups = split /\s+/, $1;
      $self->{additional_groups} = \@additional_groups;
    }    # if
  }    # for

  # Change modes to numeric
  $self->{mode} = 0;

  if ($self->{owner_mode}) {
    $self->{mode} += 400 if $self->{owner_mode} =~ /r/;
    $self->{mode} += 200 if $self->{owner_mode} =~ /w/;
    $self->{mode} += 100 if $self->{owner_mode} =~ /x/;
    $self->{mode} += 40  if $self->{group_mode} =~ /r/;
    $self->{mode} += 20  if $self->{group_mode} =~ /w/;
    $self->{mode} += 10  if $self->{group_mode} =~ /x/;
    $self->{mode} += 4   if $self->{other_mode} =~ /r/;
    $self->{mode} += 2   if $self->{other_mode} =~ /w/;
    $self->{mode} += 1   if $self->{other_mode} =~ /x/;
  }    # if

  return;
}    # updateViewInfo

sub viewPrivateStorage() {
  my ($self) = @_;

=pod

=head1 viewPrivateStorage

Returns the view private storage size for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view private storage

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewPrivateStorage});

  return $self->{viewPrivateStorage};
}    # viewPrivateStorage

sub viewPrivateStoragePct() {
  my ($self) = @_;

=pod

=head1 viewPrivateStoragePct

Returns the view private storage percent for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view private storage

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewPrivateStoragePct});

  return $self->{viewPrivateStoragePct};
}    # viewPrivateStoragePct

sub viewDatabase() {
  my ($self) = @_;

=pod

=head1 viewDatabase

Returns the view database size for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view database size

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewDatabase});

  return $self->{viewDatabase};
}    # viewDatabase

sub viewDatabasePct() {
  my ($self) = @_;

=pod

=head1 viewDatabasePct

Returns the view database percent for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view database percent

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewDatabasePct});

  return $self->{viewDatabasePct};
}    # viewDatabasePct

sub viewAdmin() {
  my ($self) = @_;

=pod

=head1 viewAdmin

Returns the view admin size for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view admin size

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewAdmin});

  return $self->{viewAdmin};
}    # viewAdmin

sub viewAdminPct() {
  my ($self) = @_;

=pod

=head1 viewAdminPct

Returns the view admin percent for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view admin percent

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewAdminPct});

  return $self->{viewAdminPct};
}    # viewAdminPct

sub viewSpace() {
  my ($self) = @_;

=pod

=head1 viewSpace

Returns the view total size for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view space

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewSpace});

  return $self->{viewSpace};
}    # viewSpace

sub viewSpacePct() {
  my ($self) = @_;

=pod

=head1 viewSpacePct

Returns the view database percent for this view.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item view space percent

=back

=for html </blockquote>

=cut

  $self->updateViewSpace unless ($self->{viewSpacePct});

  return $self->{viewSpacePct};
}    # viewSpacePct

sub updateViewSpace() {
  my ($self) = @_;

  my ($status, @output) = $Clearcase::CC->execute (
    "space -region $self->{region} -view $self->{tag}");

  $self->{viewPrivateStorage}    = 0.0;
  $self->{viewPrivateStoragePct} = '0%';
  $self->{viewAdmin}             = 0.0;
  $self->{viewAdminPct}          = '0%';
  $self->{viewDatabase}          = 0.0;
  $self->{viewDatabasePct}       = '0%';
  $self->{viewSpace}             = 0.0;
  $self->{viewSpacePct}          = '0%';

  for (@output) {
    if (/\s*(\S+)\s*(\S+)\s*View private storage/) {
      $self->{viewPrivateStorage}    = $1;
      $self->{viewPrivateStoragePct} = $2;
    } elsif (/\s*(\S+)\s*(\S+)\s*View database/) {
      $self->{viewDatabase}    = $1;
      $self->{viewDatabasePct} = $2;
    } elsif (/\s*(\S+)\s*(\S+)\s*View administration/) {
      $self->{viewAdmin}    = $1;
      $self->{viewAdminPct} = $2;
    } elsif (/\s*(\S+)\s*(\S+)\s*Subtotal/) {
      $self->{viewSpace}    = $1;
      $self->{viewSpacePct} = $2;
    }    # if
  }    # for

  return;
}    # updateViewSpace

1;

=pod

=head2 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=back

=head2 INCOMPATABILITIES

None

=head2 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Andrew@DeFaria.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.38.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
