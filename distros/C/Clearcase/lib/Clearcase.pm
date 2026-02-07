package Clearcase;

use strict;
use warnings;

our $VERSION = '1.01';

=pod

=head1 NAME

Clearcase - Object oriented interface to Clearcase.

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.43 $

=item Created

Tue Dec  4 17:33:43 MST 2007

=item Modified

$Date: 2011/11/16 18:27:37 $

=back

=head1 SYNOPSIS

Provides access to global Clearcase information in an object oriented manner as
well as an interface to cleartool.

 # Access some compile time global settings:
 print "View Drive: $Clearcase::VIEW_DRIVE" . "\n";
 print "Vob Tag Prefix: $Clearcase::VOBTAG_PREFIX" . "\n";

 # Access some run time global information through the default object
 print "Client: $Clearcase::CC->client" . "\n";
 print "Region: $Clearcase::CC->region" . "\n";
 print "Registry host: $Clearcase::CC->registry_host" . "\n";

 # List all vobs using execute method of the default object";
 my ($status, @vobs) = $Clearcase::CC->execute ("lsvob -s");

 print $_ foreach (@vobs) if $status == 0 . "\n";

=head1 DESCRIPTION

This module, and others below the Clearcase directory, implement an object
oriented approach to Clearcase. In general Clearcase entities are made into
objects that can be manipulated easily in Perl. This module is the main or
global module. Contained herein are members and methods of a general or global
nature. Also contained here is an IPC interface to cleartool such that cleartool
runs in the background and commands are fed to it via the execute method. When
making repeated calls to cleartool this can result in a substantial savings of
time as most operating systems' fork/execute sequence is time consuming. Factors
of 8 fold improvement have been measured.

Additionally a global variable, $CC, is implemented from this module such that
you should not need to instantiate another one, though you could.

=head1 ROUTINES

The following routines are exported:

=cut

use base 'Exporter';

use Carp;

use IPC::Open3;

my ($clearpid, $clearin, $clearout, $oldHandler, $cleartool);

# Inline OSDep constants
my ($ARCHITECTURE, $SEPARATOR);

BEGIN {
  $ARCHITECTURE = $^O =~ /MSWin/ ? 'windows' : $^O =~ /cygwin/ ? 'cygwin' : $^O;
  $SEPARATOR    = $^O =~ /MSWin/ ? '\\' : '/';
}

our $VIEW_DRIVE     = 'M';
our $VOB_MOUNT      = 'vob';
our $WIN_VOB_PREFIX = '\\';
our $SFX            = $ENV{CLEARCASE_XN_SFX} ? $ENV{CLEARCASE_XN_SFX} : '@@';

our $VOBTAG_PREFIX =
  ($ARCHITECTURE eq 'windows' or $ARCHITECTURE eq 'cygwin')
  ? $WIN_VOB_PREFIX
  : "/$VOB_MOUNT";
our $VIEWTAG_PREFIX =
  ($ARCHITECTURE eq 'windows' or $ARCHITECTURE eq 'cygwin')
  ? "$VIEW_DRIVE:"
  : "${SEPARATOR}view";

our ($CCHOME, $COUNTDB);

our $CC;

our @EXPORT_OK = qw (
  $CC
  $CCHOME
  $COUNTDB
  $SFX
  $VIEW_DRIVE
  $VIEWTAG_PREFIX
  $VOB_MOUNT
  $VOBTAG_PREFIX
  $WIN_VOB_PREFIX
);

# Replacement for Display
sub display {print "@_\n"; return;}
sub error   {die "ERROR: @_\n";}

BEGIN {
  # Find executables that we rely on
  if ($ARCHITECTURE eq 'windows' or $ARCHITECTURE eq 'cygwin') {

    # Should really go to the registry for this...

    # We can go to the registry pretty easy in Cygwin but I'm not sure how to do
    # that in plain old Windows. Most people either have Clearcase installed on
    # the C drive or commonly on the D drive on servers. So we'll look at both.
    $CCHOME = 'C:\\IBMRational\\RationalSDLC\\Clearcase';

    $CCHOME = 'D:\\IBMRational\\RationalSDLC\\Clearcase'
      unless -d $CCHOME;

    error 'Unable to figure out where Clearcase is installed', 1
      unless -d $CCHOME;

    $COUNTDB = "$CCHOME\\etc\\utils\\countdb.exe";
  } else {
    $CCHOME  = '/opt/rational/clearcase';
    $COUNTDB = "$CCHOME/etc/utils/countdb";
  }    # if

  #error "Unable to find countdb ($COUNTDB)", 2
  #if ! -f $COUNTDB;
}    # BEGIN

sub DESTROY {
  my $exitStatus = $?;

  if ($clearpid) {

    # Exit cleartool process
    print $clearin "exit\n";

    waitpid $clearpid, 0;
  }    # if

  local $? = $exitStatus;

  # Call old signal handler (if any)
  &$oldHandler if $oldHandler;

  return;
}    # DESTROY

# Save old interrupt handler
$oldHandler = $SIG{INT};

# Set interrupt handler
local $SIG{INT} = \&Clearcase::DESTROY;

=pod

=head2 formatOpts (%opts)

Format a hash of options into a string

Parameters:

=for html <blockquote>

=over

=item %opts

Hash of options

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $opts

String of formatted options

=back

=for html </blockquote>

=cut

=pod

=head2 formatOpts (%opts)

Format a hash of options into a string

Parameters:

=for html <blockquote>

=over

=item %opts

Hash of options

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $opts

String of formatted options

=back

=for html </blockquote>

=cut

sub formatOpts {
  my (%opts) = @_;

  my $opts = '';

  foreach (keys %opts) {
    $opts .= "$_ ";
    $opts .= "$opts{$_} "
      if $opts{$_} ne '';
  }    # foreach

  return $opts;
}    # formatOpts

=pod

=head2 setComment ($comment)

Format a comment string for cleartool or return -nc

Parameters:

=for html <blockquote>

=over

=item $comment

The comment string

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $comment_opt

Formatted comment option (e.g. -c "foo" or -nc)

=back

=for html </blockquote>

=cut

=pod

=head2 setComment ($comment)

Format a comment string for cleartool or return -nc

Parameters:

=for html <blockquote>

=over

=item $comment

The comment string

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $comment_opt

Formatted comment option (e.g. -c "foo" or -nc)

=back

=for html </blockquote>

=cut

sub setComment ($) {
  my ($comment) = @_;

  return !$comment ? '-nc' : '-c "' . quotemeta $comment . '"';
}    # setComment

sub vobname ($) {
  my ($tag) = @_;

=pod

=head2 vobname ($tag)

Given a vob tag, return the vob name by stripping of the VOBTAG_PREFIX properly
such that you return just the unique vob name. This is tricky because Windows
uses '\' as a VOBTAG_PREFIX. With '\' in there regex's like
/$Clearcase::VOBTAG_PREFIX(.+)/ to capture the vob's name minus the
VOBTAG_PREFIX fail because Perl evaluates this as just a single '\', which
escapes the '(' of the '(.+)'!

Parameters:

=for html <blockquote>

=over

=over

=item $tag

Vob tag to convert

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item $name

The unique part of the vob name

=back

=back

=for html </blockquote>

=cut

  my $name = $tag;

  # Special code because Windows $VOBTAG prefix (a \) is such a pain!
  if (substr ($tag, 0, 1) eq '\\') {
    $name = substr $tag, 1;
  } elsif (substr ($tag, 0, 1) eq '/') {
    if ($tag =~ /${Clearcase::VOBTAG_PREFIX}\/(.+)/) {
      $name = $1;
    }    # if
  }    # if

  return $name;
}    # vobname

sub vobtag ($) {
  my ($name) = @_;

=pod

=head2 vobtag ($name)

Given a vob name, add the VOBTAG_PREFIX based on the current OS.

Parameters:

=for html <blockquote>

=over

=over

=item $name

Vob name to convert

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item $tag

Vob tag

=back

=back

=for html </blockquote>

=cut

  # If the $VOBTAG_PREFIX is already there then do nothing
  if (substr ($name, 0, length $VOBTAG_PREFIX) eq $VOBTAG_PREFIX) {
    return $name;
  } else {
    return "$VOBTAG_PREFIX$name";
  }    # if
}    # vobtag

sub attributes ($$;%) {

  # TODO: Need to handle other options too
  my ($self, $type, $name, %newAttribs) = @_;

=pod

=head2 attributes ($type, $name)

Get any attributes attached to the $type:$name

Parameters:

=for html <blockquote>

=over

=over

=item $type

Type of object to look for attributes. For example, activity, baseline, etc.

=item $name

Object name to look for attributes.

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item %attributes

Hash of attribute name/values

=back

=back

=for html </blockquote>

=cut

  my $cmd = "describe -fmt \"%Na\" $type:$name";

  my ($status, @output) = $CC->execute ($cmd);

  return if $status;

  my %attributes;

  if ($output[0]) {

    # Parse output
    my $attributes = $output[0];
    my $attr_name;

    while ($attributes ne '') {
      if ($attributes =~ /^=(\"*)(.*)/) {
        if ($2 =~ /(.*?)$1(\s|$)(.*)/) {
          $attributes{$attr_name} = $1;
          $attributes = $3;
        } else {
          $attributes{$attr_name} = $2;
          $attributes = '';
        }    # if
      } elsif ($attributes =~ /^(\w+)=(.*)/) {
        $attr_name  = $1;
        $attributes = "=$2";
      } else {
        croak "Parsing error while parsing " . ref ($self) . " attributes";
      }    # if
    }    # while
  }    # if

  # Set any %newAttribs
  foreach (keys %newAttribs) {

    # TODO: What about other options like -comment?
    $cmd = "mkattr -replace -nc $_ \"";
    $cmd .= quotemeta $newAttribs{$_};
    $cmd .= "\" $type:$name";

    $CC->execute ($cmd);

    if ($CC->status) {
      croak "Unable to execute $cmd (Status: "
        . $CC->status . ")\n"
        . join ("\n", $CC->output);
    } else {
      $attributes{$_} = $newAttribs{$_};
    }    # if
  }    # foreach

  return %attributes;
}    # attributes

sub status () {
  my ($self) = @_;

=pod

=head2 status ()

Returns the status of the last executed command.

Parameters:

=for html <blockquote>

=over

=over

=item none

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item $status

Status of the command last executed.

=back

=back

=for html </blockquote>

=cut

  return $self->{status};
}    # status

sub output () {
  my ($self) = @_;

=pod

=head2 output ()

Returns the output of the last executed command.

Parameters:

=for html <blockquote>

=over

=over

=item none

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item @output or $output

If called in a list context, returns @output, otherwise returns $output.

=back

=back

=for html </blockquote>

=cut

  if (wantarray) {
    return split /\n/, $self->{output};
  } else {
    return $self->{output};
  }    # if
}    # output

# TODO: Should implement a pipe call that essentially does a cleartool command
# to a pipe allowing the user to read from the pipe. This will help with such
# cleartool command that may give back huge output or where the user wishes to
# start processing the output as it comes instead of waiting until the cleartool
# command is completely finished. Would like to do something like execute does
# with cleartool running in the background but we need to handle the buffering
# of output sending only whole lines.

sub execute {
  my ($self, $cmd) = @_;

=pod

=head2 execute ($cmd)

Sends a command to the cleartool coprocess. If not running a cleartool coprocess
is started and managed. The coprocess is implemented as a coprocess using IPC
for communication that will exist until the object is destroyed. Stdin and
stdout/stderr are therefore pipes and can be fed. The execute method feeds the
input pipe and returns status and output from the output pipe.

Using execute can speed up execution of repeative cleartool invocations
substantially.

Parameters:

=for html <blockquote>

=over

=over

=item $cmd

Cleartool command to execute.

=back

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=over

=item $status

Status of the command last executed.

=item @output

Array of output lines from the cleartool command execution.

=back

=back

=for html </blockquote>

=cut

  my ($status, @output);

  # This seems to be how most people locate cleartool. On Windows (this
  # includes Cygwin) we assume it's in our path. On Unix/Linux we assume it's
  # installed under /opt/rational/clearcase/bin. This is needed in case we wish
  # to use these Clearcase objects say in a web page where the server is often
  # run as a plain user who does not have cleartool in their path.
  unless ($cleartool) {
    if ($ARCHITECTURE =~ /Win/ or $ARCHITECTURE eq 'cygwin') {
      $cleartool = 'cleartool';
    } elsif (-x '/opt/rational/clearcase/bin/cleartool') {
      $cleartool = '/opt/rational/clearcase/bin/cleartool';
    }    # if
  }    # unless

  $cleartool ||= 'cleartool';

  # TODO: Need to catch SIGCHILD here in case the user does something like hit
  # Ctrl-C. Such an action may interrupt the underlying cleartool process and
  # kill it. But we would be unaware (i.e. $clearpid would still be set). So
  # when SIGCHILD is caught we need to undef $clearpid.
  if (!$clearpid) {

    # Simple check to see if we can execute cleartool
    @output = `$cleartool -ver 2>&1`;
    @output = ();

    return (-1, 'Clearcase not installed')
      unless $? == 0;

    $clearpid = open3 ($clearin, $clearout, $clearout, $cleartool, "-status");

    return (-1, ('Clearcase not installed')) unless $clearpid;
  }    # if

  # Execute command
  print $clearin "$cmd\n";

  # Now read output from $clearout and format the lines in to an array. Also
  # capture the status code to return it.
  while (my $line = <$clearout>) {
    if ($line !~ /(.*)Command \d+ returned status (\d+)/sm) {
      push @output, $line;
    } else {
      push @output, $1;
      $status = $2;
      last;
    }    # if
  }    # while

  if (@output) {
    chomp @output;
    chop @output if $output[0] =~ /\r$/;
  }    # if

  # We're getting extra blank lines at the bottom of @output. Not sure why
  # but we need to remove it
  pop @output
    if @output and $output[-1] eq '';

  $self->{lastcmd} = 'cleartool ' . $cmd;
  $self->{status}  = $status;
  $self->{output}  = join "\n", @output;

  return ($status, @output);
}    # execute

sub lastcmd() {
  my ($self) = @_;

=pod

=head2 lastcmd()

Return last command attempted by execute

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Last command attempted by execute

=back

=for html </blockquote>

=cut

  $self->{lastcmd} ||= '';

  return $self->{lastcmd};
}    # lastcmd

sub new {
  my ($class) = @_;

=pod

=head2 new ()

Construct a new Clearcase object. Note there is already a default
Clearcase object created named $cc. You should use that unless you
have good reason to instantiate another Clearcase object.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase object

=back

=for html </blockquote>

=cut

  # Attributes
  my ($registry_host, $version, @regions,);

  my $self = bless {
    registry_host  => $registry_host,
    version        => $version,
    verbose_level  => 0,
    vobtag_prefix  => $VOBTAG_PREFIX,
    viewtag_prefix => $VIEWTAG_PREFIX,
    regions        => \@regions,
  }, $class;

  # Get list of regions
  my ($status, @output);

  ($status, @regions) = $self->execute ('lsregion');

  return $self
    if $status;

  # Get hostinfo attributes
  ($status, @output) = $self->execute ('hostinfo -long');

  return $self
    if $status;

  foreach (@output) {
    if (/Client: (.*)/) {
      $self->{client} = lc $1;
    } elsif (/Product: (.*)/) {
      $self->{version} = $1;
    } elsif (/Operating system: (.*)/) {
      $self->{os} = $1;
    } elsif (/Hardware type: (.*)/) {
      $self->{hardware_type} = $1;
    } elsif (/Registry host: (.*)/) {
      $self->{registry_host} = $1;
    } elsif (/Registry region: (.*)/) {
      $self->{region}   = $1;
      $self->{sitename} = $1;

      if ($self->{region} =~ /(\S*)(NT|UNIX)$/) {
        $self->{sitename} = $1;
      }    # if
    } elsif (/License host: (.*)/) {
      $self->{license_host} = $1;
    }    # if
  }    # foreach

  return $self;
}    # new

# Member access methods...

sub client {
  my ($self) = @_;

=pod

=head2 client

Returns the client

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item client

=back

=for html </blockquote>

=cut

  return $self->{client};
}    # client

sub hardware_type {
  my ($self) = @_;

=pod

=head2 hardware_type

Returns the hardware_type

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item hardware_type

=back

=for html </blockquote>

=cut

  return $self->{hardware_type};
}    # hardware_type

sub license_host {
  my ($self) = @_;

=pod

=head2 license_host

Returns the license_host

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item license_host

=back

=for html </blockquote>

=cut

  return $self->{license_host};
}    # license_host

sub os {
  my ($self) = @_;

=pod

=head2 os

Returns the os

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item os

=back

=for html </blockquote>

=cut

  return $self->{os};
}    # os

sub region {
  my ($self) = @_;

=pod

=head2 region

Returns the region

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

sub registry_host {
  my ($self) = @_;

=pod

=head2 registry_host

Returns the registry_host

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item client string

=back

=for html </blockquote>

=cut

  return $self->{registry_host};
}    # registry_host

sub sitename {
  my ($self) = @_;

=pod

=head2 sitename

Returns the sitename

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item sitename

=back

=for html </blockquote>

=cut

  return $self->{sitename};
}    # sitename

sub version {
  my ($self) = @_;

=pod

=head2 version

Returns the version

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

sub regions {
  my ($self) = @_;

=pod

=head2 regions

Returns an array of regions in an array context or the number of
regions in a scalar context

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item array of regions or number of regions

=back

=for html </blockquote>

=cut

  if (wantarray) {
    my @returnArray = sort @{$self->{regions}};

    return @returnArray;
  } else {
    return scalar @{$self->{regions}};
  }    # if
}    # regions

sub pwv () {
  my ($self) = @_;

=pod

=head2 pwv

Returns the current working view or undef if not in a view

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Current working view or undef if none

=back

=for html </blockquote>

=cut

  my ($status, @output) = $self->execute ('pwv -short');

  return if $status;
  return $output[0] eq '** NONE **' ? undef : $output[0];
}    # pwv

sub name2oid ($;$) {
  my ($self, $name, $vob) = @_;

=pod

=head2 name2oid

Returns the oid for a given name

Parameters:

=for html <blockquote>

=over

=item name

The name to convert (unless filesystem object it should contain a type:)

=item vob

The vob the name belongs to

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item OID

=back

=for html </blockquote>

=cut

  if ($vob) {
    $vob = '@' . vobtag $vob;
  } else {
    $vob = '';
  }    # if

  my ($status, @output) = $self->execute ("dump $name$vob");

  return if $status;

  @output = grep {/^oid=/} @output;

  if ($output[0] =~ /oid=(\S+)\s+/) {
    return $1;
  } else {
    return;
  }    # if
}    # name2oid

sub oid2name ($$) {
  my ($self, $oid, $vob) = @_;

=pod

=head2 oid2name

Returns the object name for the given oid

Parameters:

=for html <blockquote>

=over

=item oid

The OID to convert

=item vob

The vob the OID belongs to

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item String representing the OID's textual name/value

=back

=for html </blockquote>

=cut

  $vob = vobtag $vob
    unless $vob =~ /^vobuuid:/;

  my ($status, @output) =
    $self->execute ("describe -fmt \"%n\" oid:$oid\@$vob");

  return if $status;
  return $output[0];
}    # oid2name

sub verbose_level {
  my ($self) = @_;

=pod

=head2 verbose_level

Returns the verbose_level

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item verbose_level

=back

=for html </blockquote>

=cut

  return $self->{verbose_level};
}    # verbose_level

sub quiet {
  my ($self) = @_;

=pod

=head2 quiet

Sets verbose_level to quiet

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

=cut

  $self->{verbose_level} = 0;

  return;
}    # quiet

sub noisy {
  my ($self) = @_;

=pod

=head2 noisy

Sets verbose_level to noisy

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

=cut

  $self->{verbose_level} = 1;

  return;
}    # noisy

$CC = Clearcase->new;

1;

=pod

=head1 DEPENDENCIES

=head2 Perl Modules

=head1 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=item L<Clearcase::Vob|Clearcase::Vob>

=back

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2026 by Andrew DeFaria <Andrew@DeFaria.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.38.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
