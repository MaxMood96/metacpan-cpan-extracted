
=pod

=head1 NAME Vob.pm

Object oriented interface to a Clearcase VOB

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.15 $

=item Created

Thu Dec 29 12:07:59 PST 2005

=item Modified

$Date: 2011/11/16 19:46:13 $

=back

=head1 SYNOPSIS

Provides access to information about a Clearcase VOB. Note that information
about the number of elements, branches, etc. that is provided by countdb are not
initially instantiated with the VOB object, rather those member variables are
expanded if and when accessed. This helps the VOB object to be more efficient.

 # Create VOB object
 my $vob = new Clearcase::Vob (tag => "/vobs/test");

 # Access member variables...
 print "Tag:\t\t"		. $vob->tag . "\n";
 print "Global path:\t"	. $vob->gpath . "\n";
 print "Sever host:\t"	. $vob->shost . "\n";
 print "Access:\t\t"		. $vob->access . "\n";
 print "Mount options:\t"	. $vob->mopts . "\n";
 print "Region:\t\t"		. $vob->region . "\n";
 print "Active:\t\t"		. $vob->active . "\n";
 print "Replica UUID:\t"	. $vob->replica_uuid . "\n";
 print "Host:\t\t"		. $vob->host . "\n";
 print "Access path:\t"	. $vob->access_path . "\n";
 print "Family UUID:\t"	. $vob->family_uuid . "\n";

 # This members are not initially expanded until accessed
 print "Elements:\t"		. $vob->elements . "\n";
 print "Branches:\t"		. $vob->branches . "\n";
 print "Versions:\t"		. $vob->versions . "\n";
 print "DB Size:\t"		. $vob->dbsize . "\n";
 print "Adm Size:\t"		. $vob->admsize . "\n";
 print "CT Size:\t"		. $vob->ctsize . "\n";
 print "DO Size:\t"		. $vob->dosize . "\n";
 print "Src Size:\t"		. $vob->srcsize . "\n";
 print "Size:\t\t"		. $vob->size . "\n";

 # VOB manipulation
 print "Umounting " . $vob->tag . "...\n";

 $vob->umount;

 print "Mounting " . $vob->tag . "...\n";

 $vob->mount;

=head2 DESCRIPTION

This module, and others below the Clearcase directory, implement an object
oriented approach to Clearcase. In general Clearcase entities are made into
objects that can be manipulated easily in Perl. This module is the main or
global module. Contained herein are members and methods of a general or global
nature. Also contained here is an IPC interface to cleartool such that cleartool
runs in the background andcommands are fed to it via the exec method. When
making repeated calls to cleartool this can result in a substantial savings of
time as most operating systems' fork/exec sequence is time consuming. Factors of
8 fold improvement have been measured.

Additionally a global variable, $cc, is implemented from this module such that
you should not need to instantiate another one, though you could.

=head2 ROUTINES

The following routines are exported:

=cut

package Clearcase::Vob;

use strict;
use warnings;

use Clearcase;

sub new($;$) {
  my ($class, $tag, $region) = @_;

=pod

=head2 new (tag)

Construct a new Clearcase VOB object. Note that not all members are
initially populated because doing so would be time consuming. Such
member variables will be expanded when accessed.

Parameters:

=for html <blockquote>

=over

=item tag

VOB tag to be instantiated. You can use either an object oriented call
(i.e. my $vob = new Clearcase::Vob (tag => "/vobs/test")) or the
normal call (i.e. my $vob = new Clearcase::Vob ("/vobs/test")). You
can also instantiate a new vob by supplying a tag and then later
calling the create method.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase VOB object

=back

=for html </blockquote>

=cut

  $region ||= $Clearcase::CC->region;

  $class = bless {
    tag    => $tag,
    region => $region,
  }, $class;

  $class->updateVobInfo;

  return $class;
}    # new

sub tag() {
  my ($self) = @_;

=pod

=head2 tag

Returns the VOB tag

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB's tag

=back

=for html </blockquote>

=cut

  return $self->{tag};
}    # tag

sub gpath() {
  my ($self) = @_;

=pod

=head2 gpath

Returns the VOB global path

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB's gpath

=back

=for html </blockquote>

=cut

  return $self->{gpath};
}    # gpath

sub shost() {
  my ($self) = @_;

=pod

=head2 shost

Returns the VOB server host

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB's server host

=back

=for html </blockquote>

=cut

  return $self->{shost};
}    # shost

# Alias name to tag
sub name() {
  goto &tag;
}    # name

sub access() {
  my ($self) = @_;

=pod

=head2 access

Returns the type of VOB access

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item access

Returns either public for public VOBs or private for private VOBs

=back

=for html </blockquote>

=cut

  return $self->{access};
}    # access

sub mopts() {
  my ($self) = @_;

=pod

=head2 mopts

Returns the mount options

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB's mount options

=back

=for html </blockquote>

=cut

  return $self->{mopts};
}    # mopts

sub region() {
  my ($self) = @_;

=pod

=head3 region

Returns the region for this VOB tag

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

sub active() {
  my ($self) = @_;

=pod

=head2 active

Returns that active status (whether or not the vob is currently mounted) of the
VOB

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Returns YES for an active VOB or NO for an inactive one

=back

=for html </blockquote>

=cut

  return $self->{active};
}    # active

sub replica_uuid() {
  my ($self) = @_;

=pod

=head2 replica_uuid

Returns the VOB replica_uuid

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB replica_uuid

=back

=for html </blockquote>

=cut

  return $self->{replica_uuid};
}    # replica_uuid

sub host() {
  my ($self) = @_;

=pod

=head2 host

Returns the VOB host

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB's host

=back

=for html </blockquote>

=cut

  return $self->{host};
}    # host

sub access_path() {
  my ($self) = @_;

=pod

=head2 access_path

Returns the VOB access path

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB access path

This is the path relative to the VOB's host

=back

=for html </blockquote>

=cut

  return $self->{access_path};
}    # access_path

sub family_uuid() {
  my ($self) = @_;

=pod

=head2 family_uuid

Returns the VOB family UUID

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB family UUID

=back

=for html </blockquote>

=cut

  return $self->{family_uuid};
}    # family_uuid

sub vob_registry_attributes() {
  my ($self) = @_;

=pod

=head2 vob_registry_attributes

Returns the VOB Registry Attributes

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB Registry Attributes

=back

=for html </blockquote>

=cut

  return $self->{vob_registry_attributes};
}    # vob_registry_attributes

sub expand_space() {
  my ($self) = @_;

  my ($status, @output) = $Clearcase::CC->execute ("space -vob $self->{tag}");

  # Initialize fields in case of command failure
  $self->{dbsize}  = 0;
  $self->{admsize} = 0;
  $self->{ctsize}  = 0;
  $self->{dosize}  = 0;
  $self->{srcsize} = 0;
  $self->{size}    = 0;

  for (@output) {
    if (/(\d*\.\d).*VOB database.*/) {
      $self->{dbsize} = $1;
    } elsif (/(\d*\.\d).*administration data.*/) {
      $self->{admsize} = $1;
    } elsif (/(\d*\.\d).*cleartext pool.*/) {
      $self->{ctsize} = $1;
    } elsif (/(\d*\.\d).*derived object pool.*/) {
      $self->{dosize} = $1;
    } elsif (/(\d*\.\d).*source pool.*/) {
      $self->{srcsize} = $1;
    } elsif (/(\d*\.\d).*Subtotal.*/) {
      $self->{size} = $1;
    }    # if
  }    # for

  return;
}    # expand_space

sub expand_description() {
  my ($self) = @_;

  my ($status, @output) =
    $Clearcase::CC->execute ("describe -long vob:$self->{tag}");

  for (my $i = 0; $i < @output; $i++) {
    if ($output[$i] =~ /created (\S+) by (.+) \((\S+)\)/) {
      $self->{created}   = $1;
      $self->{ownername} = $2;
      $self->{owner}     = $3;
    } elsif ($output[$i] =~ /^\s+\"(.+)\"/) {
      $self->{comment} = $1;
    } elsif ($output[$i] =~ /master replica: (.+)/) {
      $self->{masterReplica} = $1;
    } elsif ($output[$i] =~ /replica name: (.+)/) {
      $self->{replicaName} = $1;
    } elsif ($output[$i] =~ /VOB family featch level: (\d+)/) {
      $self->{featureLevel} = $1;
    } elsif ($output[$i] =~ /database schema version: (\d+)/) {
      $self->{schemaVersion} = $1;
    } elsif ($output[$i] =~ /modification by remote privileged user: (.+)/) {
      $self->{remotePrivilege} = $1;
    } elsif ($output[$i] =~ /atomic checkin: (.+)/) {
      $self->{atomicCheckin} = $1;
    } elsif ($output[$i] =~ /VOB ownership:/) {
      while ($output[$i] !~ /Additional groups:/) {
        $i++;

        if ($output[$i++] =~ /owner (.+)/) {
          $self->{owner} = $1;
        }    # if

        if ($output[$i++] =~ /group (.+)/) {
          $self->{group} = $1;
        }    # if
      }    # while

      my @groups;

      while ($output[$i] !~ /ACLs enabled/) {
        if ($output[$i++] =~ /group (.+)/) {
          push @groups, $1;
        }    # if
      }    # while

      $self->{groups} = \@groups;

      if ($output[$i++] =~ /ACLs enabled: (.+)/) {
        $self->{aclsEnabled} = $1;
      }    # if

      my %attributes;

      while ($i < @output and $output[$i] !~ /Hyperlinks:/) {
        if ($output[$i] !~ /Attributes:/) {
          my ($key, $value) = split / = /, $output[$i];

          # Trim leading spaces
          $key =~ s/^\s*(\S+)/$1/;

          # Remove unnecessary '"'s
          $value =~ s/\"(.*)\"/$1/;

          $attributes{$key} = $value;
        }    # if

        $i++;
      }    # while

      $self->{attributes} = \%attributes;

      $i++;

      my %hyperlinks;

      while ($i < @output and $output[$i]) {
        my ($key, $value) = split " -> ", $output[$i++];

        # Trim leading spaces
        $key =~ s/^\s*(\S+)/$1/;

        $hyperlinks{$key} = $value;
      }    # while

      $self->{hyperlinks} = \%hyperlinks;
    }    # if
  }    # for

  return;
}    # expand_space

sub masterReplica() {

=pod

=head2 masterReplica

Returns the VOB master replica

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB master replica

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{masterReplica};

  return $self->{masterReplica};
}    # masterReplica

sub created() {

=pod

=head2 created

Returns the date the VOB was created

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Date the VOB was created

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{created};

  return $self->{created};
}    # created

sub ownername() {

=pod

=head2 ownername

Returns the VOB ownername

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB Owner Name

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{ownername};

  return $self->{ownername};
}    # ownername

sub owner() {

=pod

=head2 owner

Returns the VOB owner

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB master replica

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{owner};

  return $self->{owner};
}    # owner

sub comment() {

=pod

=head2 comment

Returns the VOB comment

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB comment

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{comment};

  return $self->{comment};
}    # comment

sub replicaName() {

=pod

=head2 replicaName

Returns the VOB replicaName

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB replica name

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{replicaName};

  return $self->{replicaName};
}    # replicaName

sub featureLevel() {

=pod

=head2 featureLevel

Returns the VOB featureLevel

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB feature level

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{featureLevel};

  return $self->{featureLevel};
}    # featureLevel

sub schemaVersion() {

=pod

=head2 schemaVersion

Returns the VOB schemaVersion

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB schema version

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{schemaVersion};

  return $self->{schemaVersion};
}    # schemaVersion

sub remotePrivilege() {

=pod

=head2 remotePrivilege

Returns the VOB remotePrivilege

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Remote Privilege capability

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{remotePrivilege};

  return $self->{remotePrivilege};
}    # remotePrivilege

sub atomicCheckin() {

=pod

=head2 atomicCheckin

Returns the VOB atomicCheckin

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Whether atomic check in enabled

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{atomicCheckin};

  return $self->{atomicCheckin};
}    # atomicCheckin

sub group() {

=pod

=head2 group

Returns the VOB group

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB group

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{group};

  return $self->{group};
}    # group

sub groups() {

=pod

=head2 groups

Returns the VOB groups

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB groups

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{groups};

  return @{$self->{groups}};
}    # groups

sub aclsEnabled() {

=pod

=head2 aclsEnabled

Returns the VOB aclsEnabled

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB aclsEnabled

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{aclsEnabled};

  return $self->{aclsEnabled};
}    # aclsEnabled

sub attributes() {

=pod

=head2 attributes

Returns the VOB attributes

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB attributes

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{attributes};

  return %{$self->{attributes}};
}    # attributes

sub hyperlinks() {

=pod

=head2 hyperlinks

Returns the VOB hyperlinks

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item VOB hyperlinks

=back

=for html </blockquote>

=cut

  my ($self) = @_;

  $self->expand_description unless $self->{hyperlinks};

  return %{$self->{hyperlinks}};
}    # hyperlinks

sub countdb() {
  my ($self) = @_;

  # Set values to zero in case we cannot get the right values from countdb
  $self->{elements} = 0;
  $self->{branches} = 0;
  $self->{versions} = 0;

  # Countdb needs to be done in the vob's db directory
  my $cwd = `pwd`;

  chomp $cwd;
  chdir "$self->{gpath}/db";

  my $cmd    = "$Clearcase::COUNTDB vob_db 2>&1";
  my @output = `$cmd`;

  if ($? != 0) {
    chdir $cwd;
    return;
  }    # if

  chomp @output;

  # Parse output
  for (@output) {
    if (/^ELEMENT\s*:\s*(\d*)/) {
      $self->{elements} = $1;
    } elsif (/^BRANCH\s*:\s*(\d*)/) {
      $self->{branches} = $1;
    } elsif (/^VERSION\s*:\s*(\d*)/) {
      $self->{versions} = $1;
    }    # if
  }    # for

  chdir $cwd;

  return;
}    # countdb

sub elements() {
  my ($self) = @_;

=pod

=head2 elements

Returns the number of elements in the VOB (obtained via countdb)

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item number of elements

=back

=for html </blockquote>

=cut

  $self->countdb if !$self->{elements};

  return $self->{elements};
}    # elements

sub branches() {
  my ($self) = @_;

=pod

=head3 branches

Returns the number of branch types in the vob

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item number of branch types

=back

=for html </blockquote>

=cut

  $self->countdb if !$self->{branches};

  return $self->{branches};
}    # branches

sub versions() {
  my ($self) = @_;

=pod

=head2 versions

Returns the number of element versions in the VOB

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item number of element versions

=back

=for html </blockquote>

=cut

  $self->countdb if !$self->{versions};

  return $self->{versions};
}    # versions

sub dbsize() {
  my ($self) = @_;

=pod

=head3 dbsize

Returns the size of the VOB's database

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item database size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{dbsize};

  return $self->{dbsize};
}    # dbsize

sub admsize() {
  my ($self) = @_;

=pod

=head2 admsize

Returns the size of administrative data in the VOB

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item adminstrative size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{admsize};

  return $self->{admsize};
}    # admsize

sub ctsize() {
  my ($self) = @_;

=pod

=head3 ctsize

Returns the size of the cleartext pool

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item cleartext pool size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{ctsize};

  return $self->{ctsize};
}    # ctsize

sub dosize() {
  my ($self) = @_;

=pod

=head2 dosize

Returns the size of the derived object pool

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item derived object pool size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{dosize};

  return $self->{dosize};
}    # dosize

sub srcsize() {
  my ($self) = @_;

=pod

=head2 srcsize

Returns the size of the source pool

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item source pool size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{srcsize};

  return $self->{srcsize};
}    # srcsize

sub size() {
  my ($self) = @_;

=pod

=head2 size

Returns the size of the VOB

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item size

=back

=for html </blockquote>

=cut

  $self->expand_space if !$self->{size};

  return $self->{size};
}    # size

sub mount() {
  my ($self) = @_;

=pod

=head2 mount

Mount the current VOB

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

Status of the mount command

=item @output

An array of lines output from the cleartool mount command

=back

=for html </blockquote>

=cut

  return 0 if $self->{active} && $self->{active} eq "YES";

  my ($status, @output) = $Clearcase::CC->execute ("mount $self->{tag}");

  return ($status, @output);
}    # mount

sub umount() {
  my ($self) = @_;

=pod

=head3 umount

Unmounts the current VOB

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

  my ($status, @output) = $Clearcase::CC->execute ("umount $self->{tag}");

  return ($status, @output);
}    # umount

sub exists() {
  my ($self) = @_;

=pod

=head2 exists

Returns true or false if the VOB exists

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
    $Clearcase::CC->execute ("lsvob -region $self->{region} $self->{tag}");

  return !$status;
}    # exists

sub create(;$$$%) {
  my ($self, $host, $vbs, $comment, %opts) = @_;

=pod

=head2 create

Creates a VOB. First instantiate a VOB object with a tag. Then call create. A 
small subset of parameters is supported for create.

Parameters:

=for html <blockquote>

=over

=item $host (optional)

Host to create the vob on. Default is the current host.

=item $vbs (optional)

VOB storage area. This is a global pathname to the VOB storage
area. Default will attempt to use -stgloc -auto.

=item $comment (optional)

Comment for this VOB's creation. Default is -nc

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

  my ($status, @output);

  my $additionalOpts = '';

  for (keys %opts) {
    $additionalOpts .= "-$_ ";
    $additionalOpts .= "$opts{$_} " if $opts{$_};
  }    # for

  if ($host && $vbs) {
    $additionalOpts .= '-ucmproject' if $self->{ucmproject};

    ($status, @output) = $Clearcase::CC->execute (
"mkvob -tag $self->{tag} $comment $additionalOpts -host $host -hpath $vbs "
        . "-gpath $vbs $vbs");
  } else {

    # Note this requires that -stgloc's work and that using -auto is not a
    # problem.
    ($status, @output) =
      $Clearcase::CC->execute (
      "mkvob -tag $self->{tag} $comment $additionalOpts -stgloc -auto");
  }    # if

  $self->updateVobInfo;

  return ($status, @output);
}    # create

sub remove() {
  my ($self) = @_;

=pod

=head2 remove

Removed this VOB

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

  return $Clearcase::CC->execute ("rmvob -force $self->{gpath}");
}    # remove

=pod

=head2 updateVobInfo ($vob)

Updates the VOB info from cleartool lsvob

Parameters:

=for html <blockquote>

=over

=item $vob

The vob object/tag to update info for

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

=head2 updateVobInfo ($vob)

Updates the VOB info from cleartool lsvob

Parameters:

=for html <blockquote>

=over

=item $vob

The vob object/tag to update info for

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub updateVobInfo ($$) {
  my ($self) = @_;

  my ($status, @output) = $Clearcase::CC->execute ("lsvob -long $self->{tag}");

  # Assuming this vob is an empty shell of an object that the user may possibly
  # use the create method on, return our blessings...
  return if $status != 0;

  for (@output) {
    if (/Global path: (.*)/) {
      $self->{gpath} = $1;
    } elsif (/Server host: (.*)/) {
      $self->{shost} = $1;
    } elsif (/Access: (.*)/) {
      $self->{access} = $1;
    } elsif (/Mount options: (.*)/) {
      $self->{mopts} = $1;
    } elsif (/Region: (.*)/) {
      $self->{region} = $1;
    } elsif (/Active: (.*)/) {
      $self->{active} = $1;
    } elsif (/Vob tag replica uuid: (.*)/) {
      $self->{replica_uuid} = $1;
    } elsif (/Vob on host: (.*)/) {
      $self->{host} = $1;
    } elsif (/Vob server access path: (.*)/) {
      $self->{access_path} = $1;
    } elsif (/Vob family uuid:  (.*)/) {
      $self->{family_uuid} = $1;
    } elsif (/Vob registry attributes: (.*)/) {
      $self->{vob_registry_attributes} = $1;
    }    # if
  }    # for

  return;
}    # getVobInfo

1;

=pod

=head2 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=item L<OSdep|OSdep>

=back

=head2 BUGS AND LIMITATIONS

There are no known bugs in this module

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Andrew@DeFaria.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.38.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
