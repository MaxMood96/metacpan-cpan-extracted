
=pod

=head1 NAME Element.pm

Object oriented interface to Clearcase Elements

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

Provides access to information about Clearcase Elements.

 my $element = new Clearcase::Element (pname => "element");

 print "Element:\t"	. $element->pname . "\n";
 print "Version:\t"	. $element->version . "\n";
 print "Pred:\t\t"	. $element->pred . "\n";

 print "Activities:\n";

 if (my %activities = $element->activities) {
   print "\t\t$_: $activities{$_}\n" foreach (keys %activities);
 } else {
   print "\t\tNone\n";
 } # if

 print "Attributes:\n";

 if (my %attributes = $element->attributes) {
   print "\t\t$_=$attributes{$_}\n" foreach (keys %attributes);
 } else {
   print"\t\tNone\n";
 } # if

 print "Hyperlinks:\n";

 if (my @hyperlinks = $element->hyperlinks) {
   print "\t\t$_\n" foreach (@hyperlinks);
 } else {
   print "\t\tNone\n";
 } # if

 print "Comments:\n";

 if ($element->comments) {
   print "\t\t" . $element->comments . "\n";
 } else {
   print "\t\tNone\n";
 } # if

 print "Create_date:\t" . $element->create_date . "\n";
 print "User:\t\t"	  . $element->user . "\n";
 print "Group:\t\t"	  . $element->group . "\n";
 print "User_mode:\t"	  . $element->user_mode . "\n";
 print "Group_mode:\t"  . $element->group_mode . "\n";
 print "Other_mode:\t"  . $element->other_mode . "\n";
 print "Mode:\t\t"	  . $element->mode . "\n";	

 print "Labels:\n";

 if (my @labels = $element->labels) {
   print "\t\t$_\n" foreach (@labels);
 } else {
  print "\t\tNone\n";
 } # if

 print "Rule:\t\t"  . $element->rule . "\n";
 print "Xname:\t\t" . $element->xname . "\n";

=head1 DESCRIPTION

This module implements a Clearcase Element object.

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::Element;

use strict;
use warnings;

use lib '..';

use Clearcase;

sub collapseOverExtendedVersionPathname ($) {
  my ($versionStr) = @_;

=pod

=head2 collapseOverExtendedVersionPathname

This utility function will collapse an "over extended" version pathname. These
over extended pathnames can occur when we are not operating in the UCM view
from which the version was generated. Clearcase gives us enormous,technically
correct but hard to read, view/vob extended path names. Here's an example 
(broken by lines for readability):

 /vob/component/branch1@@/main/branch1_Integration/1/src/main/branch1_
 /2/com/main/branch1_Integration/2/company/main/branch1_Integration/2/
 ManagerPlatform/main/branch1_Integration/2/nma/main/
 branch1_Integration/devbranch_17/1/common/main/devbranch_17/3/exception/
 main/mainline/devbranch_r17/1/Exception.java/main/mainline/1
  
We want this to read:

  element: /vob/component/src/com/company/ManagerPlatform/nma/
           common/exception/Exception.java
  version: /main/mainline/1

Parameters:

=for html <blockquote>

=over

=item $versionStr

This is the over extended version pathname 

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item %element hash

A hash containing the element's name and version string collapsed

=back

=for html </blockquote>

=cut

  return
    unless $versionStr;

  $versionStr =~ s/\\/\//g;

  my ($name, $version) = split /$Clearcase::SFX/, $versionStr;

  my %element = (
    extended_name => $versionStr,
    name          => $name,
    version       => $version,
  );

  return
    unless $element{version};

  while ($element{version} =~ s/.*?\/\d+\/(.*?)\///) {
    $element{name} .= "/$1";
  }    # while

  $element{version} = "/$element{version}"
    if $element{version} !~ /^\//;

  return %element;
}    # collapseOverExtendedVersionPathname

sub new ($) {
  my ($class, $pname) = @_;

=pod

=head2 new

Construct a new Clearcase Element object.

Parameters:

=for html <blockquote>

=over

=item element name

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Element object

=back

=for html </blockquote>

=cut

  my $self = bless {pname => $pname,}, $class;

  my ($version, $rule);

  my ($status, @output) = $Clearcase::CC->execute ("ls -d $pname");

  return $self
    if $status;

  # Sometimes ls -d puts out more than one line. Join them...
  if ((join ' ', @output) =~ m{^.*\Q$Clearcase::SFX\E(\S+)\s+Rule: (.*)$}m) {
    $version = $1;
    $rule    = $2;
  }    # if

  $self->{rule}    = $rule;
  $self->{version} = $version;

  return $self;
}    # new

sub describe () {
  my ($self) = @_;

  # Get information that can only be gotten with describe -long. These fields
  # lack a -fmt option.

  my ($status, @output) =
    $Clearcase::CC->execute ("describe -long $self->{pname}");

  return
    if $status != 0;

  my $section;

  foreach (@output) {
    if (/Hyperlinks:/) {
      $section = 'hyperlinks';
      next;
    } elsif (/Attached activities:/) {
      $section = 'activities';
      next;
    }    # if

    if ($section) {
      if ($section eq 'activities') {
        if (/activity:(.*)\s+\"(.*)\"/) {
          ${$self->{activities}}{$1} = $2;
        }    # if
      } elsif ($section eq "hyperlinks") {
        if (/\s+(.*)/) {
          push @{$self->{hyperlinks}}, $1;
        }    # if
      }    # if

      next;
    }    # if

    if (/User : \S+\s*: (.*)/) {
      $self->{user_mode} = $1;
    } elsif (/Group: \S+\s*: (.*)/) {
      $self->{group_mode} = $1;
    } elsif (/Other:\s+: (.*)/) {
      $self->{other_mode} = $1;
    }    # if
  }    # foreach

  # Change modes to numeric
  $self->{mode} = 0;

  $self->{mode} += 400 if $self->{user_mode}  =~ /r/;
  $self->{mode} += 200 if $self->{user_mode}  =~ /w/;
  $self->{mode} += 100 if $self->{user_mode}  =~ /x/;
  $self->{mode} += 40  if $self->{group_mode} =~ /r/;
  $self->{mode} += 20  if $self->{group_mode} =~ /w/;
  $self->{mode} += 10  if $self->{group_mode} =~ /x/;
  $self->{mode} += 4   if $self->{other_mode} =~ /r/;
  $self->{mode} += 2   if $self->{other_mode} =~ /w/;
  $self->{mode} += 1   if $self->{other_mode} =~ /x/;

  return;
}    # describe

sub activities () {
  my ($self) = @_;

=pod

=head2 activities

Returns a hash of activity name/value pairs

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Hash of activity name/value pairs

=back

=for html </blockquote>

=cut

  $self->describe
    unless $self->{activities};

  return $self->{activities} ? %{$self->{activities}} : ();
}    # activities

sub attributes () {
  my ($self) = @_;

=pod

=head2 attributes

Returns a hash of attribute name/value pairs

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Hash of attribute name/value pairs

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{attributes};

  return %{$self->{attributes}};
}    # attributes

sub comments () {
  my ($self) = @_;

=pod

=head2 comments

Returns the comments associated with the current version element.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item comment

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{comments};

  return $self->{comments};
}    # comments

sub create_date () {
  my ($self) = @_;

=pod

=head2 create_date

Returns the date of creation of the element.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item create date

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{create_date};

  return $self->{create_date};
}    # create_date

sub group () {
  my ($self) = @_;

=pod

=head2 group

Returns the group of the element.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item group

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{group};

  return $self->{group};
}    # group

sub group_mode () {
  my ($self) = @_;

=pod

=head2 group_mode

Returns the group mode of the element

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item group mode

=back

=for html </blockquote>

=cut

  $self->describe
    unless $self->{group_mode};

  return $self->{group_mode};
}    # group_mode

sub hyperlinks () {
  my ($self) = @_;

=pod

=head2 hyperlinks

Returns a hash of hyperlink name/value pairs

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Hash of hyperlink name/value pairs

=back

=for html </blockquote>

=cut

  $self->describe
    unless $self->{hyperlinks};

  return @{$self->{hyperlinks}};
}    # hyperlinks

sub labels () {
  my ($self) = @_;

=pod

=head2 labels

Returns an array of labels

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Array of labels

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{labels};

  return @{$self->{labels}};
}    # labels

sub mode () {
  my ($self) = @_;

=pod

=head2 mode

Returns the numeric mode representing the element's access mode

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Array of activities

=back

=for html </blockquote>

=cut

  $self->describe
    unless $self->{mode};

  return $self->{mode};
}    # mode

sub other_mode () {
  my ($self) = @_;

=pod

=head2 other_mode

Returns the mode for other for the element.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item  A string repesenting the other mode

=back

=for html </blockquote>

=cut

  $self->describe
    unless $self->{other_mode};

  return $self->{other_mode};
}    # other_mode

sub pname () {
  my ($self) = @_;

=pod

=head2 pname

Returns the pname of the element.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item pname

=back

=for html </blockquote>

=cut

  return $self->{pname};
}    # pname

sub pred () {
  my ($self) = @_;

=pod

=head2 pred

Returns the predecessor version of this element

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Predecessor version

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{pred};

  return $self->{pred};
}    # pred

sub rule () {
  my ($self) = @_;

=pod

=head2 rule

Returns the config spec rule that selected this element's version.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item rule

=back

=for html </blockquote>

=cut

  return $self->{rule};
}    # rule

sub type () {
  my ($self) = @_;

=pod

=head2 type

Returns the element's type

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item element type

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{type};

  return $self->{type};
}    # type

sub objkind () {
  my ($self) = @_;

=pod

=head2 objkind

Returns the element's object kind

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item element's object kind

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{objkind};

  return $self->{objkind};
}    # objkind

sub oid ($) {
  my ($version) = @_;

=pod

=head2 oid

Returns the element's OID

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item element's OID

=back

=for html </blockquote>

=cut

  $version .= $Clearcase::SFX
    unless $version =~ /$Clearcase::SFX$/;

  my ($status, @output) = $Clearcase::CC->execute ('dump "' . $version . '"');

  return
    unless $status == 0;

  @output = grep {/^oid=/} @output;

  if ($output[0] =~ /oid=(.+?)\s+/) {
    return $1;
  }    # if
}    # oid

sub user () {
  my ($self) = @_;

=pod

=head2 user

Returns the username of the owner of this element.

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

  $self->updateElementInfo
    unless $self->{user};

  return $self->{user};
}    # user

sub user_mode () {
  my ($self) = @_;

=pod

=head2 user_mode

Returns the mode for the user for the element.

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

  $self->describe
    unless $self->{user_mode};

  return $self->{user_mode};
}    # user_mode

sub version () {
  my ($self) = @_;

=pod

=head2 version

Returns this element's version

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item version

=back

=for html </blockquote>

=cut

  return $self->{version};
}    # version

sub xname () {
  my ($self) = @_;

=pod

=head2 xname

Returns the view extended path name (xname) of an element version.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item xname

=back

=for html </blockquote>

=cut

  $self->updateElementInfo
    unless $self->{xname};

  return $self->{xname};
}    # xname

sub mkelem (;$) {
  my ($self, $comment) = @_;

=pod

=head2 mkelem

Returns creates a new element

Parameters:

=for html <blockquote>

=over

=item Comment

Creation comment. Default -nc.

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

  $comment = Clearcase::setComment $comment;

  return $Clearcase::CC->execute ("mkelem $comment $self->{pname}");
}    # mkelem

sub checkout (;$) {
  my ($self, $comment) = @_;

=pod

=head2 checkout

Checks out the element

Parameters:

=for html <blockquote>

=over

=item comment

Checkout comment. Default -nc.

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

  $comment = Clearcase::setComment $comment;

  return $Clearcase::CC->execute ("checkout $comment $self->{pname}");
}    # checkout

sub checkin (;$) {
  my ($self, $comment) = @_;

=pod

=head2 checkin

Checks in the element

Parameters:

=for html <blockquote>

=over

=item comment

Check in comment. Default -nc.

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

  $comment = Clearcase::setComment $comment;

  return $Clearcase::CC->execute ("checkin $comment $self->{pname}");
}    # checkout

sub updateElementInfo () {
  my ($self) = @_;

  # Get all information that can be gotten using -fmt
  my $fmt =
      'Attributes:%aEndAttributes:'
    . 'Comment:%cEndComment:'
    . 'Create_date:%dEndCreate_date:'
    . 'Group:%[group]pEndGroup:'
    . 'Labels:%NlEndLabels:'
    . 'Pred:%PSnEndPred:'
    . 'Type:%[type]pEndType:'
    . 'ObjectKind:%mEndObjectKind:'
    . 'User:%[owner]pEndUser:'
    . 'Xname:%XnEndXname:';

  my ($status, @output) =
    $Clearcase::CC->execute ("describe -fmt \"$fmt\" $self->{pname}");

  return
    unless $status == 0;

  # We need to make sure that fields are filled in or empty because we are using
  # undef as an indication that we have not called updateElementInfo yet.
  $self->{attributes} = $self->{labels} =
    ();

  $self->{comments} = $self->{create_date} = $self->{group} = $self->{pred} =
    $self->{type} = $self->{objkind} = $self->{user} = $self->{xname} = '';

  foreach (@output) {

    # This output is wrapped with parenthesis...
    if (/Attributes:\((.*)\)EndAttributes:/) {
      my @attributes = split ", ", $1;
      my %attributes;

      foreach (@attributes) {
        if (/(\w+)=(\w+)/) {
          $attributes{$1} = $2;
        }    # if
      }    # foreach

      $self->{attributes} = %attributes ? \%attributes : ();
    }    # if

    if (/Comments:(.*)EndComments:/) {
      $self->{comments} = $1;
    }    # if

    if (/Create_date:(.*)EndCreate_date:/) {
      $self->{create_date} = $1;
    }    # if

    if (/Group:(.*)EndGroup:/) {
      $self->{group} = $1;
    }    # if

    if (/Labels:(.*)EndLabels:/) {
      my @labels = split " ", $1;
      $self->{labels} = @labels ? \@labels : ();
    }    # if

    if (/Pred:(.*)EndPred:/) {
      $self->{pred} = $1;
    }    # if

    if (/Type:(.*)EndType:/) {
      $self->{type} = $1;
    }    # if

    if (/ObjectKind:(.*)EndObjectKind:/) {
      $self->{objkind} = $1;
    }    # if

    if (/User:(.*)EndUser:/) {
      $self->{user} = $1;
    }    # if

    if (/Xname:(.*)EndXname:/) {
      $self->{xname} = $1;
    }    # if
  }    # foreach

  return;
}    # updateElementInfo

1;

=head2 DEPENDENCIES

=head2 Modules

=over

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
