package Clearquest::Server;

use strict;
use warnings;

=pod

=head1 NAME Server.pm

Clearquest Server - Provide access to Clearquest database

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 2.6 $

=item Created

Monday, October 10, 2011  5:02:07 PM PDT

=item Modified

2013/03/14 23:13:33

=back

=head1 SYNOPSIS

Provides an interface to the Clearquest database over the network.

This library implements both the daemon portion of the server and the client 
API.

=head1 DESCRIPTION

The server allows both read and write access to a Clearquest database as defined
in cq.conf file. Note the username/password must be of a user who can write to 
the Clearquest database for write access to succeed.

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
use POSIX qw(:sys_wait_h :signal_h);
use Clearquest::Utils;

use Clearquest;

# We cannot use parent here because CQPerl is used by the server. As such cqperl
# doesn't have parent.pm!
our @ISA = 'Clearquest';

our $VERSION = '$Revision: 2.6 $';
($VERSION) = ($VERSION =~ /\$Revision: (.*) /);

=pod

=head2 new (;%)

Create a new server object

Parameters:

=for html <blockquote>

=over

=item %parms

Configuration parameters

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $self

The new object

=back

=for html </blockquote>

=cut

sub new (;%) {
  my ($class, %parms) = @_;

  my $self;

  $parms{CQ_DATABASE} ||= $Clearquest::OPTS{CQ_DATABASE};
  $parms{CQ_USERNAME} ||= $Clearquest::OPTS{CQ_USERNAME};
  $parms{CQ_PASSWORD} ||= $Clearquest::OPTS{CQ_PASSWORD};
  $parms{CQ_DBSET}    ||= $Clearquest::OPTS{CQ_DBSET};
  $parms{CQ_SERVER}   ||= $Clearquest::OPTS{CQ_SERVER};
  $parms{CQ_PORT}     ||= $Clearquest::OPTS{CQ_PORT};

  $parms{CQ_MULTITHREADED} = $Clearquest::OPTS{CQ_MULTITHREADED}
    unless defined $parms{CQ_MULTITHREADED};

  # The server always uses the standard Clearquest API
  $parms{CQ_MODULE} = 'api';

  # Set data members
  $self->{username}      = $parms{CQ_USERNAME};
  $self->{password}      = $parms{CQ_PASSWORD};
  $self->{database}      = $parms{CQ_DATABASE};
  $self->{dbset}         = $parms{CQ_DBSET};
  $self->{server}        = $parms{CQ_SERVER};
  $self->{port}          = $parms{CQ_PORT};
  $self->{module}        = $parms{CQ_MODULE};
  $self->{multithreaded} = $parms{CQ_MULTITHREADED};
  $self->{verbose}       = $ENV{VERBOSE} || 0;
  $self->{debug}         = $ENV{DEBUG}   || 0;

  return bless $self, $class;
}    # new

sub _tag ($) {
  my ($self, $msg) = @_;

  my $tag = strftime "%Y-%m-%d %H:%M:%S", localtime;
  $tag .= ' ';
  $tag .= $self->{pid} ? '[' . abs ($self->{pid}) . '] ' : '';

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
  debug "Entered _funeral";

  while (my $childpid = waitpid (-1, WNOHANG) > 0) {
    my $status = $?;

    if ($childpid != -1) {
      local $SIG{CHLD} = \&_funeral;

      my $msg = 'Child has died';
      $msg .= $status ? " with status $status" : '';

      verbose "[$childpid] $msg"
        if $status;
    }    # if
  }    # while

  return;
}    # _funeral

sub _endServer () {
  display "Clearquest::Server V$VERSION shutdown at " . localtime;

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

sub _printStatus ($) {
  my ($self, $client) = @_;

  my $status = $self->{clearquest}->error;

  $status ||= 0;

  $self->_debug ("Printing status: " . __PACKAGE__ . " Status: $status");

  print $client __PACKAGE__ . " Status: $status\n";

  $self->_debug ("After print");

  return;
}    # printStatus

sub _connectToClearquest ($$$$) {
  my ($self, $database, $username, $password, $dbset) = @_;

  my %parms;

  $parms{CQ_DATABASE} = $database;
  $parms{CQ_USERNAME} = $username;
  $parms{CQ_PASSWORD} = $password;
  $parms{CQ_DBSET}    = $dbset;

  # The server always uses the standard Clearquest API
  $parms{CQ_MODULE} = 'api';

  # Connect to Clearquest database
  $self->{clearquest} = Clearquest->new (%parms);

  $self->_verbose ("Connecting to "
      . "$parms{CQ_USERNAME}\@$parms{CQ_DATABASE}/$parms{CQ_DBSET}"
      . " for $self->{clientname}");

  $self->{loggedin} = $self->{clearquest}->connect;

  return $self->{loggedin};
}    # _connectToClearquest

sub _processCommand ($$@) {
  my ($self, $client, $call, @parms) = @_;

  $self->_debug ("Client wishes to execute $call");

  if ($call eq 'end') {
    $self->_verbose ("Serviced requests from $self->{clientname}");

    close $client;

    $self->disconnectFromClient;

    return 1;
  } elsif ($call eq 'open') {
    debug "connectToClearquest";
    unless ($self->_connectToClearquest (@parms)) {
      debug "Error: " . $self->{clearquest}->errmsg;
      print $client $self->{clearquest}->errmsg . "\n";
    } else {
      debug "Success!";
      print $client 'Connected to '
        . $self->username () . '@'
        . $self->database () . '/'
        . $self->dbset () . "\n";
    }    # if

    debug "Calling _printStatus";
    $self->_printStatus ($client);
  } elsif ($call eq 'get') {
    my %record = $self->{clearquest}->get (@parms);

    unless ($self->{clearquest}->error) {
      foreach my $field (keys %record) {

        # TODO: Need to handle field types better...
        if (ref $record{$field} eq 'ARRAY') {
          foreach (@{$record{$field}}) {

            # Change \n's to &#10;
            s/\r\n/&#10;/gm;

            print $client "$field\@\@$_\n";
          }    # foreach
        } else {

          # Change \n's to &#10;
          $record{$field} =~ s/\r\n/&#10;/gm;

          print $client "$field\@\@$record{$field}\n";
        }    # if
      }    # foreach
    } else {
      print $client $self->{clearquest}->errmsg . "\n";
    }    # unless

    $self->_printStatus ($client);
  } elsif ($call eq 'find') {
    my ($result, $nbrRecs) = $self->{clearquest}->find (@parms);

    if ($self->{clearquest}->error != 0) {
      print $client $self->{clearquest}->errmsg . "\n";
    } else {

      # Store away $result so we can use it later
      $self->{result} = $result;

      print $client "$result\n$nbrRecs\n";
    }    # if

    $self->_printStatus ($client);
  } elsif ($call eq 'getnext') {
    my %record = $self->{clearquest}->getNext ($self->{result});

    unless ($self->{clearquest}->error) {
      foreach my $field (keys %record) {

        # TODO: Need to handle field types better...
        if (ref $record{$field} eq 'ARRAY') {
          foreach (@{$record{$field}}) {

            # Change \n's to &#10;
            s/\r\n/&#10;/gm;

            print $client "$field\@\@$_\n";
          }    # foreach
        } else {

          # Change \n's to &#10;
          $record{$field} =~ s/\r\n/&#10;/gm;

          print $client "$field\@\@$record{$field}\n";
        }    # if
      }    # foreach
    } else {
      print $client $self->{clearquest}->errmsg . "\n";
    }    # unless

    $self->_printStatus ($client);
  } elsif ($call eq 'getdynamiclist') {

    # TODO Better error handling/testing
    my @entry = $self->{clearquest}->getDynamicList (@parms);

    print $client "$_\n" foreach @entry;

    $self->_printStatus ($client);
  } elsif ($call eq 'dbsets') {

    # TODO Better error handling/testing
    print $client "$_\n" foreach ($self->{clearquest}->DBSets);

    $self->_printStatus ($client);
  } elsif ($call eq 'key') {

    # TODO Better error handling/testing
    print $client $self->{clearquest}->key (@parms) . "\n";

    $self->_printStatus ($client);
  } elsif ($call eq 'modify' or $call eq 'modifyDBID') {
    my $table  = shift @parms;
    my $key    = shift @parms;
    my $action = shift @parms;

    # Need to turn off strict for eval here...
    my ($values, @ordering);
    no strict;         ## no critic (ProhibitNoStrict)
    eval $parms[0];    ## no critic (ProhibitStringyEval)

    $values = $VAR1;
    use strict;

    @ordering = @{$parms[1]} if ref $parms[1] eq 'ARRAY';

    my $errmsg;

    if ($call eq 'modify') {
      $errmsg =
        $self->{clearquest}->modify ($table, $key, $action, $values, @ordering);
    } elsif ($call eq 'modifyDBID') {
      $errmsg = $self->{clearquest}
        ->modifyDBID ($table, $key, $action, $values, @ordering);
    }    # if

    print $client "$errmsg\n" if $errmsg ne '';

    $self->_printStatus ($client);
  } elsif ($call eq 'add') {
    my $dbid = $self->{clearquest}->add (@parms);

    if ($self->{clearquest}->error) {
      print $client 'ERROR: ' . $self->{clearquest}->errmsg () . "\n";
    }    # if

    $self->_printStatus ($client);
  } elsif ($call eq 'delete') {
    $self->{clearquest}->delete (@parms);

    if ($self->{clearquest}->error) {
      print $client 'ERROR: ' . $self->{clearquest}->errmsg () . "\n";
    }    # if

    $self->_printStatus ($client);
  } else {
    $self->{clearquest}->{errnbr} = -1;
    $self->{clearquest}->{errmsg} = "Unknown call $call";

    print $client $self->{clearquest}->errmsg . "\n";

    $self->_printStatus ($client);
  }    # if

  return;
}    # _processCommand

sub _serviceClient ($) {
  my ($self, $client) = @_;

  $self->_verbose ("Servicing requests from $self->{clientname}");

  # Set autoflush for client
  $client->autoflush if $client;

  my $line;

  $self->_debug ("Reading request from client");

  while ($line = <$client>) {
    $self->_debug ("Request read: $line");

    if ($line) {
      chomp $line;
      chop $line if $line =~ /\r$/;
    } else {
      $self->_verbose ("Host $self->{clientname} went away!");

      close $client;

      return;
    }    # if

    if ($line =~ /^shutdown/i) {
      if ($self->{server}) {
        $self->_verbose (
          "$self->{clientname} requested to shutdown the server");

        print $client __PACKAGE__ . " Status: 0\n";
      }    # if

      # TODO: This is not working because getppid is not implemented on Windows!
      #kill HUP => getppid;

      exit 1;
    }    # if

    # Parse command line
    my ($call, @parms);

    if ($line =~ /^\s*(\S+)\s+(.*)/) {
      $call = lc $1;

      no strict;    ## no critic (ProhibitNoStrict)
      eval $2;      ## no critic (ProhibitStringyEval)

      @parms = @$VAR1;
      use strict;

      my $i = 0;

      foreach (@parms) {
        if (/^\$VAR1/) {
          no strict;    ## no critic (ProhibitNoStrict)
          eval;         ## no critic (ProhibitStringyEval)

          $parms[$i++] = $VAR1;
          use strict;
        } else {
          $i++;
        }    # if
      }    # foreach
    } elsif ($line =~ /^\s*(\S+)/) {
      $call  = lc $1;
      @parms = ();
    } else {
      my $errmsg = "Garbled command line: '$line'";

      if ($self->{clearquest}) {
        $self->{clearquest}->{errnbr} = -1;
        $self->{clearquest}->{errmsg} = $errmsg;

        print $client $self->{clearquest}->errmsg . "\n";
      } else {
        print "$errmsg\n";
      }    # if

      $self->_printStatus ($client);

      return;
    }    # if

    $self->_debug ("Processing command $call @parms");

    last if $self->_processCommand ($client, $call, @parms);
  }    # while

  return;
}    # _serviceClient

sub multithreaded (;$) {
  my ($self, $newValue) = @_;

  my $oldValue = $self->{multithreaded};

  $self->{multithreaded} = $newValue if $newValue;

  return $oldValue;
}    # multithreaded

sub disconnectFromClient () {
  my ($self) = @_;

  # Destroy Clearquest object so we disconnect from Clearquest.
  undef $self->{clearquest};

  $self->_verbose ("Disconnected from client $self->{clientname}")
    if $self->{clientname};

  undef $self->{clientname};

  return;
}    # disconnectFromClient

sub DESTROY () {
  my ($self) = @_;

  $self->disconnectFromClient;

  if ($self->{socket}) {
    close $self->{socket};

    undef $self->{socket};
  }    # if
}    # DESTROY

=pod

=head2 startServer ()

Start the server loop

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

sub startServer () {
  my ($self) = @_;

  # Create new socket to communicate to clients with
  $self->{socket} = IO::Socket::INET->new (
    Proto     => 'tcp',
    LocalPort => $self->{port},
    Listen    => SOMAXCONN,
    ReuseAddr => 1,
  );

  error "Could not create socket - $!", 1
    unless $self->{socket};

  # Announce ourselves
  $self->_log (__PACKAGE__ . " V$VERSION accepting clients at " . localtime);

  $SIG{HUP} = \&_endServer;

  # Now wait for an incoming request
  my $client;

  LOOP: while () {
    $client = $self->{socket}->accept;

    if ($? == -1) {
      if ($!{EINTR}) {
        next;
      } else {
        error "Accept called failed (Error: $?) - $!", 1;
      }    # if
    }    # if

    my $hostinfo = gethostbyaddr $client->peeraddr;

    $self->{clientname} = $hostinfo ? $hostinfo->name : $client->peerhost;

    $self->_verbose ("$self->{clientname} is requesting service");

    if ($self->multithreaded) {
      $self->{pid} = $$;

      my $childpid;

      $self->_debug ("Spawning child to handle request");

      error "Can't fork: $!"
        unless defined ($childpid = fork);

      if ($childpid) {
        $self->{pid} = $$;

        # Signal handling sucks under Windows. For example, we cannot catch
        # SIGCHLD when using the ActiveState based cqperl when running on
        # Windows. If there will be a zombie apocalypse it will start on
        # Windows! ;-)
        unless ($^O =~ /win/i) {
          my $sigset = POSIX::SigSet->new (&POSIX::SIGCHLD);
          my $sigaction =
            POSIX::SigAction->new (\&_funeral, $sigset, &POSIX::SA_RESTART);
        }    # unless

        $self->_debug ("Parent produced child [$childpid]");
      } else {

        # In child process - ServiceClient
        $self->{pid} = $$;

        # Now exec the caller but set STDIN to be the socket. Also pass
        # -serviceClient to the caller which will need to handle that and call
        # _serviceClient.
        $self->_debug ("Client: $client");
        open STDIN, '+<&', $client
          or croak "Unable to dup client";

        my $cmd =
"cqperl \"$FindBin::Bin/$FindBin::Script -serviceClient=$self->{clientname} -verbose -debug";

        $self->_debug ("Execing: $cmd");

        exec 'cqperl', "\"$FindBin::Bin/$FindBin::Script\"",
          "-serviceClient=$self->{clientname}", '-verbose', '-debug'
          or croak "Unable to exec $cmd";
      }    # if
    } else {
      $self->_serviceClient ($client);
    }    # if
  }    # while

  # On Windows we can't catch SIGCHLD so we need to loop around. Ugly!
  goto LOOP if $^O =~ /win/i;
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
