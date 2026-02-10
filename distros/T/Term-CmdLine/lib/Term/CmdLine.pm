use v5.20;
use warnings;
use feature 'signatures';
no warnings 'experimental';

=pod

=head1 NAME CmdLine

Library to implement generic command line interface

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Created

Fri May 13 15:23:37 PDT 2011

=back

=head1 SYNOPSIS

Provides an interface to a command line utilizing Term::ReadLine and
Term::ReadLine::Gnu. Note, the latter is not part of Perl core and
must be downloaded from CPAN. Without Term::ReadLine::Gnu a lot of
functionality doesn't work.

CmdLine uses a hash to describe what your valid commands are along
with help and longer help, i.e. description strings. If you do not
define your commands then no command name completion nor help will be
available.

 use FindBin;
 use CmdLine;

 my %cmds = (
  list => (
     help        => 'help [<cmd>]',
     description => 'This is a longer description of the list command',
  ),
  execute => (
     help        => 'execute <cmd>',
     description => 'Longer description of the execute command',
  ),
 );

 # Create a new cmdline:
 my $cmdline = Term::CmdLine->new ($FindBin::Script, %cmds);

 while (my $cmd = $cmdline->get) {
   ...
 } # while

=head1 DESCRIPTION

This module implements a command line stack using Term::ReadLine and
Term::ReadLine::Gnu. If Term::ReadLine::Gnu is not installed then many
of the functions do not work. Command completion if commands are
defined with a hash as shown above.

=head1 DEFAULT COMMANDS

The for a list of the builtin commands see %builtin_cmds below

Additionally !<n> will re-exeucte a comand from history and !<cmd>
will execute <cmd> as a shell command.

=cut

package Term::CmdLine;

use base 'Exporter';

our $VERSION = '2.00';

use Carp;
use Config;
use FindBin;
use Term::ReadLine;
use Term::ANSIColor qw(color);

# OS-dependent constants (subsumed from OSDep.pm)
our $ARCHITECTURE =
  $^O =~ /MSWin/ ? 'windows' : $^O =~ /cygwin/ ? 'cygwin' : $^O;
our $NULL  = $^O =~ /MSWin/ ? 'NUL' : '/dev/null';
our $TRUE  = 1;
our $FALSE = 0;

# Display module variables and functions (subsumed from Display.pm)
my ($me, $verbose, $debug, $trace);

BEGIN {
  $me = $FindBin::Script;
  $me =~ s/\.pl$//;
  $verbose = $ENV{VERBOSE};
  $debug   = $ENV{DEBUG};
  $trace   = $ENV{TRACE};
}    # BEGIN

sub get_me() {
  return $me;
}    # get_me

sub display ($msg = '', $handle = undef, $nolinefeed = undef) {
  $handle = *STDOUT unless $handle;
  binmode $handle, ':encoding(UTF-8)';
  print $handle $msg;
  print $handle "\n" unless $nolinefeed;
  return;
}    # display

sub display_nolf ($msg, $handle = undef) {
  display $msg, $handle, "nolf";
  return;
}    # display_nolf

sub display_error ($msg, $errno = undef, $handle = undef, $nolinefeed = undef) {
  $msg ||= '';
  $handle = *STDERR if !$handle;

  unless ($errno) {
    if ( ($handle and -t $handle)
      or (-t *STDERR) and ($Config{perl} ne 'ratlperl'))
    {
      $msg =
          color ('cyan')
        . $me
        . color ('reset') . ': '
        . color ('red') . 'ERROR'
        . color ('reset')
        . ": $msg";
    } else {
      $msg = "$me: ERROR: $msg";
    }
  } else {
    if ( ($handle and -t $handle)
      or (-t *STDERR) and ($Config{perl} ne 'ratlperl'))
    {
      $msg =
          color ('cyan')
        . $me
        . color ('reset') . ': '
        . color ('red')
        . "ERROR #$errno"
        . color ('reset')
        . ": $msg";
    } else {
      $msg = "$me: ERROR #$errno: $msg";
    }
  } ## end else

  binmode $handle, ':encoding(UTF-8)';
  print $handle $msg;
  print $handle "\n" if !$nolinefeed;
  return;
}    # display_error

sub error ($msg, $errno = undef, $handle = undef, $nolinefeed = undef) {
  display_error $msg, $errno, $handle, $nolinefeed;
  exit $errno if $errno;
  return;
}    # error

sub warning ($msg, $errno = undef, $handle = undef, $nolinefeed = undef) {
  $msg ||= '';

  unless ($errno) {
    if ( ($handle and -t $handle)
      or (-t *STDERR) and ($Config{perl} ne 'ratlperl'))
    {
      $msg =
          color ('cyan')
        . $me
        . color ('reset') . ': '
        . color ('yellow')
        . 'WARNING'
        . color ('reset')
        . ": $msg";
    } else {
      $msg = "$me: WARNING: $msg";
    }
  } else {
    if ( ($handle and -t $handle)
      or (-t *STDERR) and ($Config{perl} ne 'ratlperl'))
    {
      $msg =
          color ('cyan')
        . $me
        . color ('reset') . ': '
        . color ('yellow')
        . "WARNING #$errno"
        . color ('reset')
        . ": $msg";
    } else {
      $msg = "$me: WARNING #$errno: $msg";
    }
  } ## end else

  binmode $handle, ':encoding(UTF-8)';
  print $handle $msg;
  print $handle "\n" if !$nolinefeed;
  return;
}    # warning

sub PageOutput (@output) {

  if ($ENV{PAGER}) {
    if (open my $pager, '|-', $ENV{PAGER}) {
      print $pager "$_\n" for (@output);
      close $pager;
    } else {
      print "$_\n" for (@output);
    }
  } else {
    print "$_\n" for (@output);
  }

  return;
}    # PageOutput

# Share %opts
our %opts;

# Package globals
my $_pos = 0;
my $_haveGnu;

my (%_cmds, $_cmdline, $_attribs);

BEGIN {
  # See if we can load Term::ReadLine::Gnu
  eval {require Term::ReadLine::Gnu};

  if ($@) {
    warning
"Unable to load Term::ReadLine::Gnu\nCmdLine functionality will be limited!";
    $_haveGnu = 0;
  } else {
    $_haveGnu = 1;
  }    # if
}    # BEGIN

my %builtin_cmds = (
  history => {
    help        => 'history [[start] [end]]',
    description =>
"Displays cmd history. You can specify where to <start> and where to <end>\n"
      . "Default is to list only the last screen full lines of history (as denoted\n"
      . "by \$LINES).",
  },

  help => {
    help        => 'help [<cmd>]',
    description => 'Displays help.',
  },

  helpall => {
    help        => 'helpall',
    description => 'Display all help, including builtin commands',
  },

  savehist => {
    help        => 'savehist [file] [[start] [end]]',
    description =>
"Saves a section of the history to a file. You can specify where to <start>\n"
      . "and where to <end>. Default is to save all of the history to the specified\n"
      . "file.",
  },

  get => {
    help        => 'get [var]',
    description => 'Gets a variable.',
  },

  set => {
    help        => 'set [var]=[expression]',
    description =>
      'Sets a variable. Note that expression can be any valid expression.',
  },

  vars => {
    help        => 'vars',
    description => 'Displays all known variables.',
  },

  source => {
    help        => 'source [file]',
    description => 'Run commands from a file.',
  },

  color => {
    help        => 'color [(on|off)]',
    description =>
      'Turn on|off color. With no options displays status of color.',
  },

  trace => {
    help        => 'trace [(on|off)]',
    description =>
      'Turn on|off tracing. With no options displays status of trace.',
  },

  exit => {
    help        => 'exit',
    description => 'Exit the command line interface.',
  },

  quit => {
    help        => 'quit',
    description => 'Exit the command line interface (alias for exit).',
  },
);

sub _cmdCompletion ($text, $state) {

  return unless %_cmds;

  $_pos = 0 unless $state;

  my @cmds = keys %_cmds;

  for (; $_pos < @cmds;) {
    return $cmds[$_pos - 1]
      if $cmds[$_pos++] =~ /^$text/i;
  }    # for

  return;
}    # _cmdCompletion

sub _complete ($text, $line, $start, $end) {

  return $_cmdline->completion_matches ($text, \&Term::CmdLine::_cmdCompletion);
}    # _complete

sub _gethelp ($self) {

  return unless %_cmds;

  my $line = $_cmdline->{line_buffer};

  # Trim
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;

  display '';

  # Sometimes we are called by ReadLine's callback and can't pass $self
  if (ref $self eq 'CmdLine') {
    $self->help ($line);
  } else {
    $Term::CmdLine::cmdline->help ($line);
  }    # if

  $_cmdline->on_new_line;

  return;
}    # _gethelp

sub _interpolate ($self, $str) {

  # Skip interpolation for the perl command (Note this is raid specific)
  return $str
    if $str =~ /^\s*perl\s*/i;

  while ($str =~ /\$/) {
    if ($str =~ /\$(\w+)/) {
      my $varname = $1;

      if (defined $self->{vars}{$varname}) {
        if ($self->{vars}{$varname} =~ / /) {
          $str =~ s/\$$varname/\'$self->{vars}{$varname}\'/;
        } else {
          $str =~ s/\$$varname/$self->{vars}{$varname}/;
        }    # if
      } else {
        $str =~ s/\$$varname//;
      }    # if
    }    # if
  }    # while

  return $str;
}    # _interpolate

sub _builtinCmds ($self, $line) {

  unless ($line) {
    display '';
    return 'exit';
  }    # unless

  my ($cmd, $result);

  # Short circut "psuedo" commands of !<n> and !<shellcmd>
  if ($line =~ /^\s*!\s*(\d+)/) {
    $line = $self->history ('redo', $1);
  } elsif ($line =~ /^\s*!\s*(\S+)\s*(.*)/) {
    if ($2) {
      system "$1 $2";
    } else {
      system $1;
    }    # if

    return;
  }    # if

  if ($line =~ /^\s*(\S+)/) {
    $cmd = $1;
  }    # if

  return
    unless $cmd;

  # Search for matches of partial commands
  my $foundCmd;

  for (keys %builtin_cmds) {
    if ($_ eq $cmd) {

      # Exact match - honor it
      $foundCmd = $cmd;
      last;
    } elsif (/^$cmd/) {

      # Command matched partially
      unless ($foundCmd) {

        # Found first instance of a match
        $foundCmd = $_;
      } else {

        # Found second instance of a match - $cmd is not unique
        undef $foundCmd;
        last;
      }    # unless
    }    # if
  }    # for

  # If we found a command, substitute it into line
  if ($foundCmd) {
    $line =~ s/^\s*$cmd\s*/$foundCmd /;
    $cmd = $foundCmd;
  }    # if

  if ($builtin_cmds{$cmd}) {
    if ($line =~ /^\s*helpall\s*$/i) {
      $self->help ('', 1);
    } elsif ($line =~ /^\s*help\s*(.*)/i) {
      if ($1 =~ /(.+)$/) {
        $self->help ($1);
      } else {
        $self->help;
      }    # if
    } elsif ($line =~ /^\s*history\s*(.*)/i) {
      if ($1 =~ /(\d+)\s+(\d+)\s*$/) {
        $self->history ('list', $1, $2);
      } elsif ($1 =~ /^\s*$/) {
        $self->history ('list');
      } else {
        error "Invalid usage";
        $self->help ('history');
      }    # if
    } elsif ($line =~ /^\s*savehist\s*(.*)/i) {
      if ($1 =~ /(\S+)\s+(\d+)\s+(\d+)\s*$/) {
        $self->history ('save', $1, $2, $3);
      } else {
        error 'Invalid usage';
        $self->help ('savehist');
      }    # if
    } elsif ($line =~ /^\s*get\s*(.*)/i) {
      if ($1 =~ (/^\$*(\S+)\s*$/)) {
        my $value = $self->_get ($1);

        if ($value) {
          display "$1 = $value";
        } else {
          error "$1 is not set";
        }    # if
      } else {
        error 'Invalid usage';
        $self->help ('get');
      }    # if
    } elsif ($line =~ /^\s*set\s*(.*)/i) {
      if ($1 =~ /^\$*(\S+)\s*=\s*(.*)/) {
        $self->_set ($1, $2);
      } else {
        error 'Invalid usage';
        $self->help ('set');
      }    # if
    } elsif ($line =~ /^\s*source\s+(\S+)/i) {
      $result = $self->source ($1);
    } elsif ($line =~ /^\s*vars\s*/) {
      $self->vars ($line);
    } elsif ($line =~ /^\s*color\s*(.*)/i) {
      if ($1 =~ /(1|on)/i) {
        $opts{color} = 1;
        delete $ENV{ANSI_COLORS_DISABLED}
          if $ENV{ANSI_COLORS_DISABLED};
      } elsif ($1 =~ /(0|off)/i) {
        $opts{trace} = 0;
        local $ENV{ANSI_COLORS_DISABLED} = 1;
      } elsif ($1 =~ /\s*$/) {
        if ($ENV{ANSI_COLORS_DISABLED}) {
          display 'Color is currently off';
        } else {
          display 'Color is currently on';
        }    # if
      } else {
        error 'Invalid usage';
        $self->help ('color');
      }    # if
    } elsif ($line =~ /^\s*trace\s*(.*)/i) {
      if ($1 =~ /(1|on)/i) {
        $opts{trace} = 1;
      } elsif ($1 =~ /(0|off)/i) {
        $opts{trace} = 0;
      } elsif ($1 =~ /\s*$/) {
        if ($opts{trace}) {
          display 'Trace is currently on';
        } else {
          display 'Trace is currently off';
        }    # if
      } else {
        error 'Invalid usage';
        $self->help ('trace');
      }    # if
    } elsif ($line =~ /^\s*(exit|quit)\s*$/i) {

      # Signal exit to the get() method
      return ('__EXIT__', $line, $result);
    }    # if
  }    # if

  return ($cmd, $line, $result);
}    # _builtinCmds

sub _interrupt() {

  # Announce that we have hit an interrupt
  print color ('yellow') . "<Control-C>\n" . color ('reset');

  # Free up all of the line state info
  $_cmdline->free_line_state;

  # Allow readline to clean up
  $_cmdline->cleanup_after_signal;

  # Redisplay prompt on a new line
  $_cmdline->on_new_line;
  $_cmdline->{line_buffer} = '';
  $_cmdline->redisplay;

  return;
}    # _interrupt

sub _displayMatches ($matches, $num_matches, $max_length) {

  # Work on a copy... (Otherwise we were getting "Attempt to free unreferenced
  # scalar" internal errors from perl)
  my @Matches;

  push @Matches, $_ for (@$matches);

  my $match = shift @Matches;

  if ($match =~ /^\s*(.*) /) {
    $match = $1;
  } elsif ($match =~ /^\s*(\S+)$/) {
    $match = '';
  }    # if

  my %newMatches;

  for (@Matches) {

    # Get next word
    s/^$match//;

    if (/(\w+)/) {
      $newMatches{$1} = $1;
    }    # if
  }    # for

  my @newMatches = sort keys %newMatches;

  unshift @newMatches, $match;

  $_cmdline->display_match_list (\@newMatches);
  $_cmdline->on_new_line;
  $_cmdline->redisplay;

  return;
}    # _displayMatches

sub new ($class, $histfile = undef, $eval = undef, %cmds) {

=pod

=head2 new ()

Construct a new CmdLine object. Note there is already a default
CmdLine object created named $cmdline. You should use that unless you
have good reason to instantiate another CmdLine object.

Parameters:

=for html <blockquote>

=over

=item $histfile

Set to a file name where to write the history file. If not defined no
history is kept.

=item %cmds

A hash describing the valid commands and their help/description
strings.

 my %cmds = (
  'list' => {
     help        => 'List all known commands',
     description => 'This is a longer description
                     of the list command',
  },
  'help' => {
     help        => 'This is a help command',
     description => 'help <cmd>
                     Longer description of help',
  },
 );

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item CmdLine object

=back

=for html </blockquote>

=cut

  my $me = get_me;

  $histfile ||= "$ENV{HOME}/.${me}_hist";

  my $self = bless {histfile => $histfile,}, $class;

  error "Creating bogus .${me}_hist file!"
    if $me eq '-' or $me eq '';

  unless (-f $histfile) {
    open my $hist, '>', $histfile
      or error "Unable to open $histfile for writing - $!", 1;

    close $hist;
  }    # unless

  # Instantiate a commandline
  $_cmdline = Term::ReadLine->new ($me);

  # Store the function pointer of what to call when sourcing a file or
  # evaluating an expression.
  if ($eval) {
    if (ref $eval eq 'CODE') {
      $self->{eval} = $eval;
    } else {
      error
"Invalid function pointer\nUsage: CmdLine->new ($histfile, $eval, %cmds)",
        1;
    }    # if
  }    # if

  # Default prompt is "$me:"
  $self->{prompt} = "$me:";

  # Set commands
  $self->set_cmds (%cmds);

  # Set some ornamentation
  $_cmdline->ornaments ('s,e,u,') unless $Config{cppflags} =~ /win32/i;

  # Read in history
  $self->set_histfile ($histfile);

  # Generator function for completion matches
  $_attribs = $_cmdline->Attribs;

  $_attribs->{attempted_completion_function} = \&Term::CmdLine::_complete;
  $_attribs->{completion_display_matches_hook} =
    \&Term::CmdLine::_displayMatches;
  $_attribs->{completer_word_break_characters} =~ s/ //
    if $_attribs->{completer_word_break_characters};

  # The following functionality requires Term::ReadLine::Gnu
  if ($_haveGnu) {

    # Bind a key to display completion
    $_cmdline->add_defun ('help-on-command', \&Term::CmdLine::_gethelp,
      ord ("\cl"));

    # Save a handy copy of RL_PROMPT_[START|END]_IGNORE
    $self->{ignstart} = $_cmdline->RL_PROMPT_START_IGNORE;
    $self->{ignstop}  = $_cmdline->RL_PROMPT_END_IGNORE;
  }    # if

  if ($Config{cppflags} =~ /win32/i) {
    $opts{trace} = 0;
    local $ENV{ANSI_COLORS_DISABLED} = 1;
  }    # if

  return $self;
}    # new

sub get ($self) {

=pod

=head2 get

Retrieves a command line

Parameters:

=for html <blockquote>

=over

=item None

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $cmds

=back

=for html </blockquote>

=cut

  my ($cmd, $line, $result);

  do {
    # Substitute cmdnbr into prompt if we find a '\#'
    my $prompt = $self->{prompt};

    $prompt =~ s/\\\#/$self->{cmdnbr}/g;

    use POSIX;

    # Term::ReadLine::Gnu restarts whatever system call it is using, such that
    # once we ctrl C, we don't get back to Perl until the user presses enter,
    # finally whereupon we get our signal handler called. We use sigaction
    # instead to use the old perl unsafe signal handling, but only in this read
    # routine. Sure, sigaction poses race conditions, but you'd either be at a
    # prompt or executing whatever command your prompt prompted for. The user
    # has said "Abort that!" with his ctrl-C and we're attempting to honor that.

    # Damn Windows can't do any of this
    my $oldaction;

    if ($Config{cppflags} !~ /win32/i) {
      my $sigset    = POSIX::SigSet->new;
      my $sigaction = POSIX::SigAction->new (\&_interrupt, $sigset, 0);

      $oldaction = POSIX::SigAction->new;

      # Set up our unsafe signal handler
      POSIX::sigaction (&POSIX::SIGINT, $sigaction, $oldaction);
    }    # if

    $line = $_cmdline->readline ($prompt);

    # Handle EOF (^D) - return empty list to signal exit
    return () unless defined $line;

    # Restore the old signal handler
    if ($Config{cppflags} !~ /win32/i) {
      POSIX::sigaction (&POSIX::SIGINT, $oldaction);
    }    # if

    $line = $self->_interpolate ($line)
      if $line;

    $self->{cmdnbr}++ unless $self->{sourcing};

    ($cmd, $line, $result) = $self->_builtinCmds ($line);

    # Handle exit/quit commands - return empty list to signal exit
    return () if $cmd eq '__EXIT__';

    $line = '' unless $cmd;
  } while ($cmd and $builtin_cmds{$cmd});

  return ($line, $result);
}    # get

sub set_cmds ($self, %cmds) {

=pod

=head2 set_cmds

Sets the cmds

Parameters:

=for html <blockquote>

=over

=item %cmds

New commands to use

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  %_cmds = %cmds;

  # Add in builtins
  for (keys %builtin_cmds) {
    $_cmds{$_}{help}        = $builtin_cmds{$_}{help};
    $_cmds{$_}{description} = $builtin_cmds{$_}{description};
  }    # for

  return;
}    # set_cmds

sub set_prompt ($self, $prompt) {

=pod

=head2 set_prompt

Sets the prompt

Parameters:

=for html <blockquote>

=over

=item $new_prompt

New commands to use

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $old_prompt

=back

=for html </blockquote>

=cut

  my $return = $self->{prompt};

  $self->{prompt} = $prompt;

  return $return;
}    # set_prompt

sub set_histfile ($self, $histfile) {

=pod

=head2 set_histfile

Sets the histfile

Parameters:

=for html <blockquote>

=over

=item $histfile

New commands to use

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  if ($histfile and -f $histfile) {
    $self->{histfile} = $histfile;

    if ($_haveGnu) {

      # Clear old history (if any);
      $_cmdline->clear_history;

      # Now read histfile
      $_cmdline->ReadHistory ($histfile);
    }    # if

    # Determine the number of lines in the history file
    open my $hist, '<', $histfile
      or croak "Unable to open history file $histfile";

    # Set cmdnbr
    for (<$hist>) { }
    $self->{cmdnbr} = $. + 1;

    close $hist;
  }    # if

  return;
}    # set_histfile

sub set_eval ($self, $eval = undef) {

=pod

=head2 set_eval

Sets the eval function pointer

Parameters:

=for html <blockquote>

=over

=item [\&function]

Function to set eval to. This function will be called with the command
line as the only paramter and it should return a result.

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item \&old_eval

=back

=for html </blockquote>

=cut

  my $returnEval = $self->{eval};

  $self->{eval} = $eval;

  return $returnEval;
}    # set_eval

sub help ($self, $cmd = undef, $builtins = undef) {

=pod

=head2 help [<cmd>]

Displays help

Note that the user does not need to explicitly call help - Term::CmdLine's
get method will already sense that the builtin help command was
invoked and handle it. This method is provided if the caller wishes to
call this internally for some reason.

Parameters:

=for html <blockquote>

=over

=item $cmd

Optional command help

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  my @help;

  $builtins ||= 0;

  $cmd ||= '';
  $cmd =~ s/^\s+//;
  $cmd =~ s/\s+$//;

  if ($cmd =~ /^\s*(.+)/) {
    my ($searchStr, $helpFound);

    $searchStr = $1;

    for (sort keys %_cmds) {
      if (/$searchStr/i) {
        $helpFound = 1;

        my $cmdcolor = $builtin_cmds{$_} ? color ('cyan') : color ('magenta');

        $cmd = "$cmdcolor$_";
        $cmd .= " $_cmds{$_}{parms}" if $_cmds{$_}{parms};
        $cmd .= color ('reset');
        $cmd .= " - $_cmds{$_}{help}" if $_cmds{$_}{help};

        push @help, $cmd;

        if ($_cmds{$_}{description}) {
          push @help, "  $_" for (split /\n/, $_cmds{$_}{description});
        }    # if
      }    # if
    }    # for

    unless ($helpFound) {
      display "I don't know about $cmd";

      return;
    }    # if
  } else {
    for (sort keys %_cmds) {
      next if $builtin_cmds{$_} and not $builtins;

      my $cmdcolor = $builtin_cmds{$_} ? color ('cyan') : color ('magenta');

      my $cmd = "$cmdcolor$_";
      $cmd .= " $_cmds{$_}{parms}" if $_cmds{$_}{parms};
      $cmd .= color ('reset');
      $cmd .= " - $_cmds{$_}{help}" if $_cmds{$_}{help};

      push @help, $cmd;

      if ($_cmds{$_}{description}) {
        push @help, "  $_" for (split /\n/, $_cmds{$_}{description});
      }    # if
    }    # for
  }    # if

  $self->handleOutput ($cmd, @help);

  return;
}    # help

sub history ($self, $action = undef) {

=pod

=head2 history <action> [<file>] [<start> <end>]

This method lists, saves or executes (redo) a command from the history
stack. <action> can be one of 'list', 'save' or 'redo'. If listing
history one can specify the optional <start> and <end> parameters. If
saving then <file> must be specified and optionally <start> and
<end>. If redoing a command then only <start> or the command number
should be specified.

Note that the user does not need to explicitly call history -
CmdLine's get method will already sense that the builtin history
command was invoked and handle it. This method is provided if the
caller wishes to call this internally for some reason.

Parameters:

=for html <blockquote>

=over

=item $action

One of 'list', 'save' or 'redo'

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  if ($Config{cppflags} =~ /win32/i) {
    warning 'The history command does not work on Windows (sorry)';

    return;
  }    # if

  my ($file, $start, $end);

  if ($action eq 'list') {
    $start = $_[2];
    $end   = $_[3];
  } elsif ($action eq 'save') {
    $file  = $_[2];
    $start = $_[3];
    $end   = $_[4];
  } elsif ($action eq 'redo') {
    $_cmdline->remove_history ($_cmdline->where_history);

    my $nbr  = $_[2];
    my $line = $_cmdline->history_get ($nbr);

    $_cmdline->add_history ($line);
    display $line;

    my ($cmd, $result) = $self->_builtinCmds ($line);

    if ($builtin_cmds{$cmd}) {
      return;
    } else {
      return $line;
    }    # if
  } else {
    error "Unknown action $action in history";
    return;
  }    # if

  my $current = $_cmdline->where_history;

  my $lines = ($ENV{LINES} ? $ENV{LINES} : 24) - 2;

  $start = $current - $lines
    unless defined $start;
  $start = 1
    if $start < 1;
  $end = $current
    unless defined $end;
  $end = 1
    if $end < 1;

  if ($start > $end) {
    error "Start ($start) is > end ($end)";
    help ('history');
  } else {
    my $savefile;

    if ($action eq 'save') {
      unless ($file) {
        error "Usage: savehist <file> [<start> <end>]";
        return;
      }    # unless

      if (-f $file) {
        display_nolf "Overwrite $file (yN)? ";

        my $response = <STDIN>;

        unless ($response =~ /(y|yes)/i) {
          display "Not overwritten";
          return;
        }    # unless
      }    # if

      my $success = open $savefile, '>', $file;

      unless ($success) {
        error "Unable to open history file $file - $!";
        return;
      }    # unless
    }    # if

    for (my $pos = $start; $pos <= $end; $pos++) {
      my $histline = $_cmdline->history_get ($pos);

      last unless $histline;

      if ($action eq 'list') {
        display "$pos) $histline";
      } else {
        print $savefile "$histline\n";
      }    # if
    }    # for

    close $savefile
      if $action eq 'save';
  }    # if

  return;
}    # history

sub _get ($self, $name) {

=pod

=head2 _get ($name)

This method gets a variable to a value stored in the Term::CmdLine
object.

Parameters:

=for html <blockquote>

=over

=item $name

Name of the variable

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $value

=back

=for html </blockquote>

=cut

  return $self->{vars}{$name};
}    # _get

sub _set ($self, $name, $value = undef) {

=pod

=head2 _set ($name, $value)

This method sets a variable to a value stored in the Term::CmdLine
object. Note $value will be evaluated if eval is set.

Parameters:

=for html <blockquote>

=over

=item $name

Name of the variable

=item $value

Value of the variable

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item $oldvalue

=back

=for html </blockquote>

=cut

  my $returnValue = $self->{vars}{$name};

  if (defined $value) {
    $value = $self->_interpolate ($value);

    # Do not call eval if we are setting result - otherwise we recurse
    # infinitely.
    unless ($name eq 'result') {
      no strict;
      $value = $self->{eval}($value) if $self->{eval};
      use strict;
    }    # unless

    $self->{vars}{$name} = $value;
  } else {
    delete $self->{vars}{$name};
  }    # if

  return $returnValue;
}    # _set

sub vars ($self, $pattern = undef) {

=pod

=head2 vars ($name)

This method will print out all known variables

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  my @output;

  push @output, "$_ = $self->{vars}{$_}" for (keys %{$self->{vars}});

  $self->handleOutput ($pattern, @output);

  return;
}    # vars

sub handleOutput ($self, $line, @output) {

=pod

=head2 handleOutput ($line, @output)

This method will handle outputing the array @output. It also handles redirection
(currently only output redirection) and piping

Parameters:

=for html <blockquote>

=over

=item $line

The command line used to produce @output. This method parses out redirection 
(i.e. > and >>) and piping (|) from $cmd

=item @output

The output produced by the command to redirect or pipe. (Note this isn't true
piping in that command must run first and produce all of @output before we are
called. Need to look into how to use Perl's pipe command here).

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Nothing

=back

=for html </blockquote>

=cut

  my ($outToFile, $pipeToCmd);

  # Handle piping and redirection
  if ($line =~ /(.*)\>{2}\s*(.*)/) {
    $line      = $1;
    $outToFile = ">$2";
  } elsif ($line =~ /(.*)\>{1}\s*(.*)/) {
    $line      = $1;
    $outToFile = $2;
  } elsif ($line =~ /(.*?)\|\s*(.*)/) {
    $line      = $1;
    $pipeToCmd = $2;
  }    # if

  # Store @output
  $self->{output} = \@output;

  if ($pipeToCmd) {
    my $pipe;

    local $SIG{PIPE} = 'IGNORE';

    open $pipe, '|', $pipeToCmd
      or undef $pipe;

    # TODO: Not handling the output here. Need open2 and then recursively call
    # handleOutput.
    if ($pipe) {
      print $pipe "$_\n" for (@output);

      close $pipe
        or error "Unable to close pipe for $pipeToCmd - $!";
    } else {
      error "Unable to open pipe for $pipeToCmd - $!";
    }    # if
  } else {
    unless ($outToFile) {
      PageOutput @output;
    } else {
      open my $output, '>', $outToFile;

      if ($output) {
        print $output "$_\n" for (@output);

        close $output;

        undef $outToFile;
      } else {
        error "Unable to open $outToFile for writing - $!";
      }    # if
    }    # unless
  }    # if

  return;
}    # handleOutput

sub source ($self, $file = undef) {

=pod

=head2 source <file>

This method opens a file and sources it's content by executing each
line. Note that the user must have set $self->{eval} to a function
pointer. The function will be called with one parameter - the command
line to execute. The function will return the result from the
execution of the final command.

Note that the user does not need to explicitly call source -
CmdLine's get method will already sense that the builtin source
command was invoked and handle it. This method is provided if the
caller wishes to call this internally for some reason.

Parameters:

=for html <blockquote>

=over

=item $file

Filename to source

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Returns the result of the last command executed

=back

=for html </blockquote>

=cut

  unless (-f $file) {
    error "Unable to open file $file - $!";
    return;
  }    # unless

  open my $source, '<', $file;

  my $result;

  $self->{sourcing} = 1;

  my $i = 0;

  while (<$source>) {
    chomp;

    $i++;

    my $prompt = $self->{prompt};

    $prompt =~ s/\\\#/$file:$i/;

    display "$prompt$_" if $Term::CmdLine::opts{trace};

    next if /^\s*($|\#)/;

    $_ = $self->_interpolate ($_);

    # Check to see if it's a builtin
    my ($cmd, $line, $result) = $self->_builtinCmds ($_);

    next if $builtin_cmds{$cmd};

    no strict;
    $result = $self->{eval}($line);
    use strict;

    if (defined $result) {
      if (ref \$result eq 'SCALAR') {
        PageOutput (split /\n/, $result);
      } else {
        display "Sorry but I cannot display structured results";
      }    #  if
    }    # if
  }    # while

  $self->{sourcing} = 0;

  close $source;

  return $result;
}    # source

sub DESTROY {
  my ($self) = @_;

  $_cmdline->WriteHistory ($self->{histfile})
    if $_cmdline and $_haveGnu;

  return;
}    # DESTROY

# Default cmdline instance (commented out to avoid Term::ReadLine::Gnu singleton issues)
# Users should create their own instance with: my $cmdline = Term::CmdLine->new;
# our $cmdline = Term::CmdLine->new;

1;

=pod

=head1 DEPENDENCIES

=head2 Perl Modules

=head2 CPAN Perl Modules

L<Term::ReadLine>

L<Term::ANSIColor>

L<Term::ReadLine::Gnu> (optional, but recommended for full functionality)

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module
``
Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 LICENSE AND COPYRIGHT


=cut
