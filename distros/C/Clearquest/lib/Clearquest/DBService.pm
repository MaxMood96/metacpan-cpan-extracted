package Clearquest::DBService;

use strict;
use warnings;

=pod

=head1 NAME DBService.pm

DB Service - Provide access to Clearquest database

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.2 $

=item Created

Monday, October 10, 2011  5:02:07 PM PDT

=item Modified

2011/12/31 02:13:37

=back

=head1 SYNOPSIS

Provides an interface to the Clearquest database over the network.

This library implements both the daemon portion of the server and the client
API.

=head1 DESCRIPTION

The server allows both read and write access to a Clearquest database as defined
in cqdservice.conf file. Note the username/password must be of a user who can
write to the Clearquest database for write access to succeed.

A hash is passed into to the execute method, which the client should use to talk
to the server, that describes relatively simple protocol to tell the server what
action to perform. In both the read case and the read/write case a field named
id should be defined that has a value of "<record>=<id>" (e.g.
"defect=BUGDB00034429").

For the read case the rest of the keys are the names of the fields to retrieve
with values that are undef'ed. For read/write, the rest of hash contains name
value pairs of fields to set and their values.

Execute returns a status and a hash of name value pairs for the read case and an
array of lines for any error messages for the read/write case.

=head1 ROUTINES

The following methods are available:

=cut

use Carp;
use File::Basename;
use FindBin;
use IO::Socket;
use Net::hostent;
use POSIX qw(:sys_wait_h);
use Clearquest::Utils;

# Seed options from config file

# Seed options from config file
my $config = $ENV{CQD_CONF} || '/etc/clearcase/cqdservice.conf';

sub _load_config {
  my ($file) = @_;
  my %opts;
  open my $fh, '<', $file or return %opts;
  while (<$fh>) {
    chomp;
    next if /^\s*#/;
    next if /^\s*$/;
    if (/^([^:]+):\s*(.*)$/) {
      $opts{$1} = $2;
    }
  } ## end while (<$fh>)
  close $fh;
  return %opts;
} ## end sub _load_config

croak "Unable to find config file $config" unless -r $config;

our %OPTS = _load_config ($config);

our $VERSION = '$Revision: 1.2 $';
($VERSION) = ($VERSION =~ /\$Revision: (.*) /);

# Override options if in the environment
$OPTS{CQD_HOST} = $ENV{CQD_HOST}
  if $ENV{CQD_HOST};
$OPTS{CQD_PORT} = $ENV{CQD_PORT}
  if $ENV{CQD_PORT};
$OPTS{CQD_MULTITHREADED} = $ENV{CQD_MULTITHREADED}
  if defined $ENV{CQD_MULTITHREADED};
$OPTS{CQD_DATABASE} = $ENV{CQD_DATABASE}
  if $ENV{CQD_DATABASE};
$OPTS{CQD_USERNAME} = $ENV{CQD_USERNAME}
  if $ENV{CQD_USERNAME};
$OPTS{CQD_PASSWORD} = $ENV{CQD_PASSWORD}
  if $ENV{CQD_PASSWORD};
$OPTS{CQD_DBSET} = $ENV{CQD_DBSET}
  if $ENV{CQD_DBSET};

sub new () {
  my ($class) = @_;

  my $cqdservice = bless {}, $class;

  $cqdservice->{multithreaded} = $OPTS{CQD_MULTITHREADED};
  $cqdservice->{verbose}       = $ENV{VERBOSE} || 0;
  $cqdservice->{debug}         = $ENV{DEBUG}   || 0;

  return $cqdservice;
}    # new

sub _tag ($) {
  my ($self, $msg) = @_;

  my $tag = strftime "%Y-%m-%d %H:%M:%S", localtime;
  $tag .= ' ';
  $tag .= $self->{pid} ? "[$self->{pid}] " : '';

  return "$tag$msg";
}    # _tag

sub _verbose ($) {
  my ($self, $msg) = @_;

  print $self->_tag ($msg) . "\n" if $self->{verbose};

  return;
}    # _verbose

sub _debug ($) {
  my ($self, $msg) = @_;

  print $self->_tag ($msg) . "\n" if $self->{debug};

  return;
}    # _debug

sub _log ($) {
  my ($self, $msg) = @_;

  print $self->_tag ($msg) . "\n";

  return;
}    # log

sub _funeral () {
  debug 'Entered _funeral';

  while (my $childpid = waitpid (-1, WNOHANG) > 0) {
    my $status = $?;

    debug "childpid: $childpid - status: $status";

    if ($childpid != -1) {
      local $SIG{CHLD} = \&_funeral;

      my $msg = 'Child has died';
      $msg .= $status ? " with status $status" : '';

      verbose "[$childpid] $msg"
        if $status;
    } else {
      debug "All children reaped";
    }    # if
  }    # while

  return;
}    # _funeral

sub _endServer () {
  display "CQDService V$VERSION shutdown at " . localtime;

  # Kill process group
  kill 'TERM', -$$;

  # Wait for all children to die
  while (wait != -1) {

    # do nothing
  }    # while

  # Now that we are alone, we can simply exit
  exit;
}    # _endServer

sub _restartServer () {

  # Not sure what to do on a restart server
  display 'Entered _restartServer';

  return;
}    # _restartServer

sub setMultithreaded ($) {
  my ($self, $value) = @_;

  my $oldValue = $self->{multithreaded};

  $self->{multithreaded} = $value;

  return $oldValue;
}    # setMultithreaded

sub getMultithreaded () {
  my ($self) = @_;

  return $self->{multithreaded};
}    # getMultithreaded

=pod

=head2 connectToServer (;$$)

Connects to the CQD Service

Parameters:

=for html <blockquote>

=over

=item $host

Host to connect to

=item $port

Port to connect to

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $success

1 if successful, 0 otherwise

=back

=for html </blockquote>

=cut

sub connectToServer (;$$) {
  my ($self, $host, $port) = @_;

  $host ||= $OPTS{CQD_HOST};
  $port ||= $OPTS{CQD_PORT};

  $self->{socket} = IO::Socket::INET->new (
    Proto    => 'tcp',
    PeerAddr => $host,
    PeerPort => $port,
  );

  return unless $self->{socket};

  $self->{socket}->autoflush;

  $self->{host} = $host;
  $self->{port} = $port;

  return $self->{socket} ? 1 : 0;
}    # connectToServer

=pod

=head2 disconnectFromServer ()

Disconnects from the CQD Service

Parameters:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub disconnectFromServer () {
  my ($self) = @_;

  if ($self->{socket}) {
    close $self->{socket};

    undef $self->{socket};
  }    # if

  return;
}    # disconnectFromServer

# TODO: This function should not be internal and it should be overridable
sub _serviceClient ($$) {
  my ($self, $host, $client) = @_;

  $self->_verbose ("Serving requests from $host");

  # Set autoflush for client
  $client->autoflush
    if $client;

  # Input is simple and consists of the following:
  #
  # <recordType>=<ID>
  # <fieldname>=<fieldvalue>
  # <fieldname>+=<fieldvalue>
  # ...
  # end
  #
  # Notes: <ID> can be <ID_scope>. Also a += means append this fieldvalue to
  # the existing value for the field.

  # First get record line
  my $line = <$client>;

  if ($line) {
    chomp $line;
    chop $line if $line =~ /\r$/;
  } else {
    $self->_verbose ("Host $host went away!");

    close $client;

    return;
  }    # if

  if ($line =~ /stopserver/i) {
    if ($self->{server}) {
      $self->_verbose ("$host requested to stop server [$self->{server}]");

      # Send server hangup signal
      kill 'HUP', $self->{server};
    } else {
      $self->_verbose ('Shutting down server');

      print $client "CQDService Status: 0\n";

      exit;
    }    # if
  }    # if

  my ($record, $id) = split /=/, $line;

  unless ($id) {
    $self->_verbose ('Garbled record line - rejected request');

    close $client;

    return;
  }    # unless

  $self->_verbose ("Client wishes to deal with $id");

  my $scope;

  if ($id =~ /_(\S+)/) {
    $scope = $1;
  }    # if

  $self->_debug ("$host wants $record:$id");

  my ($read, %fields);

  # Now read name/value pairs
  while () {

    # Read command from client
    $line = <$client>;

    if ($line) {
      chomp $line;
      chop $line if $line =~ /\r$/;
    } else {
      $self->_verbose ("Host $host went away!");

      close $client;

      return;
    }    # if

    last if $line =~ /^end$/i;

    # Collect name/values. Note if only names are requested then we will instead
    # return data.
    my ($name, $value) = split /=/, $line;

    if ($value) {

      # Transform %0A's back to \n
      $value =~ s/\%0A/\n/g;

      $self->_verbose ("Will set $name to $value");
    } else {
      $read = 1;
      $self->_verbose ("Will retrieve $name");
    }    # if

    $fields{$name} = $value;
  }    # while

  # Get record
  my $entity;

  $self->_verbose ("Getting $record:$id");

  eval {$entity = $self->{session}->GetEntity ($record, $id)};

  unless ($entity) {
    print $client "Unable to GetEntity $record:$id\n";

    close $client;

    return;
  }    # unless

  if ($read) {
    print $client "$_@@" . $entity->GetFieldValue ($_)->GetValue . "\n"
      for (keys %fields);
    print $client "CQD Status: 0\n";

    close $client;

    return;
  }    # if

  # Edit record
  $self->_verbose ("Editing $id");

  $entity->EditEntity ('Backend');

  my $status;

  for my $fieldName (keys %fields) {
    if ($fieldName =~ /(.+)\*$/) {
      my $newValue = delete $fields{$fieldName};

      $fieldName = $1;

      $fields{$fieldName} =
        $entity->GetFieldValue ($fieldName)->GetValue . $newValue;
    }    # if

    $self->_verbose ("Setting $fieldName to $fields{$fieldName}");

    $status = $entity->SetFieldValue ($fieldName, $fields{$fieldName});

    if ($status ne '') {
      $self->_verbose ($status);

      print $client "$status\n";
      print $client "CQD Status: 1\n";

      close $client;

      return;
    }    # if
  }    # for

  $self->_verbose ("Validating $id");

  $status = $entity->Validate;

  if ($status eq '') {
    $self->_verbose ('Committing');
    $entity->Commit;

    print $client "Successfully updated $id\n";
    print $client "CQD Status: 0\n";
  } else {
    $self->_verbose ('Reverting changes');
    $entity->Revert;
    print $client "$status\n";
    print $client "CQD Status: 1\n";
  }    # if

  close $client;

  $self->_verbose ("Serviced requests from $host");

  return;
}    # _serviceClient

=pod

=head2 execute (%)

Execute a command against the CQD Service

Parameters:

=for html <blockquote>

=over

=item %request

Request parameters

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item ($status, @output)

Status and output/error message

=back

=for html </blockquote>

=cut

sub execute (%) {
  my ($self, %request) = @_;

  $self->connectToServer or croak 'Unable to connect to CQD Service';

  return (-1, 'Unable to talk to server')
    unless $self->{socket};

  my ($status, @output) = (-1, ());

  my $server = $self->{socket};

  my $id = delete $request{id};

  print $server "$id\n";

  my $read;

  for (keys %request) {
    if ($request{$_}) {
      print $server "$_=$request{$_}\n";
    } else {
      $read = 1;
      print $server "$_\n";
    }    # if
  }    # for

  print $server "end\n";

  my ($response, %output);

  while (defined ($response = <$server>)) {
    if ($response =~ /CQD Status: (-*\d+)/) {
      $status = $1;
      last;
    }    # if

    if ($read) {
      chomp $response;
      chop $response if $response =~ /\r$/;

      my ($field, $value) = split /\@\@/, $response;

      $output{$field} = $value;
    } else {
      push @output, $response;
    }    # if
  }    # while

  chomp @output unless $read;

  $self->disconnectFromServer;

  if ($status != 0 or $read == 0) {
    return ($status, @output);
  } else {
    return ($status, %output);
  }    # if
}    # execute

=pod

=head2 startServer (;$$$$$)

Starts the CQD Service

Parameters:

=for html <blockquote>

=over

=item $port

Port to listen on

=item $username

Mantra username

=item $password

Mantra password

=item $db

Database name

=item $dbset

Database set name

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub startServer (;$$$$$) {

  require Clearquest;

  my ($self, $port, $username, $password, $db, $dbset) = @_;

  $port     ||= $OPTS{CQD_PORT};
  $username ||= $OPTS{CQD_USERNAME};
  $password ||= $OPTS{CQD_PASSWORD};
  $db       ||= $OPTS{CQD_DATABASE};
  $dbset    ||= $OPTS{CQD_DBSET};

  # Create new socket to communicate to clients with
  $self->{socket} = IO::Socket::INET->new (
    Proto     => 'tcp',
    LocalPort => $port,
    Listen    => SOMAXCONN,
    Reuse     => 1
  );

  error "Could not create socket - $!", 1
    unless $self->{socket};

  # Connect to Clearquest database
  $self->{session} = CQSession::Build ();

  verbose "Connecting to $username\@$db";

  $self->{session}->UserLogon ($username, $password, $db, $dbset);

  # Announce ourselves
  $self->_log ("CQD V$VERSION accepting clients at " . localtime);

  # Now wait for an incoming request
  LOOP:
  my $client;

  while ($client = $self->{socket}->accept) {
    my $hostinfo = gethostbyaddr $client->peeraddr;
    my $host     = $hostinfo ? $hostinfo->name : $client->peerhost;

    $self->_verbose ("$host is requesting service");

    if ($self->getMultithreaded) {
      $self->{server} = $$;

      my $childpid;

      $self->_debug ("Spawning child to handle request");

      error "Can't fork: $!"
        unless defined ($childpid = fork);

      if ($childpid) {
        $self->{pid} = $$;

        $SIG{CHLD} = \&_funeral;
        $SIG{HUP}  = \&_endServer;
        $SIG{USR2} = \&_restartServer;

        $self->_debug ("Parent produced child [$childpid]");
      } else {

        # In child process - ServiceClient
        $self->{pid} = $$;

        $self->_debug         ("Calling _serviceClient");
        $self->_serviceClient ($host, $client);
        $self->_debug         ("Returned from _serviceClient - exiting...");

        exit;
      }    # if
    } else {
      $self->_serviceClient ($host, $client);
    }    # if
  }    # while

  # This works but I really don't like it. The parent should have looped back to
  # the while statement thus waiting for the next client. But it doesn't seem to
  # do that. Instead, when multithreaded, the child exits above and then the
  # parent breaks out of the while loop. I'm not sure why this is happening.
  # This goto fixes this up but it's sooooo ugly!
  goto LOOP;
}    # startServer

1;

=pod

=head1 CONFIGURATION AND ENVIRONMENT

DEBUG: If set then $debug is set to this level.

VERBOSE: If set then $verbose is set to this level.

TRACE: If set then $trace is set to this level.

=head1 DEPENDENCIES

=head2 Perl Modules

L<Carp>

L<File::Basename|File::Basename>

L<FindBin>

L<IO::Socket|IO::Socket>

L<Net::hostent|Net::hostent>

L<POSIX>

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2026 Andrew DeFaria <Andrew@DeFaria.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone else, you are strictly prohibited from removing any
copyright notice from that Modified Version.

Copyright Holder makes no, and expressly disclaims any, representation
or warranty, should the Package be used for any purpose.  The liability
of the Copyright Holder is limited to the maximum extent permitted by
law.

=cut
