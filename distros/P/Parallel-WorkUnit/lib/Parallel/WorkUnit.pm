#
# Copyright (C) 2015-2024 Joelle Maslak
# All Rights Reserved - See License
#

package Parallel::WorkUnit;
$Parallel::WorkUnit::VERSION = '2.243480';
use v5.8;

# ABSTRACT: Provide multi-paradigm forking with ability to pass back data

use strict;
use warnings;
use autodie;

use Carp;

use overload;
use IO::Handle;
use IO::Pipely qw(pipely);
use IO::Select;
use POSIX ':sys_wait_h';
use Scalar::Util qw(blessed reftype weaken);
use Storable;
use Try::Tiny;


my @ALL_WU;    # Holds all active work units so child processes can't
               # mess with parent work units
               # Note it holds a reference (strong) to a reference
               # (weak).


sub use_anyevent {
    if ( $#_ == 0 ) {
        return shift->{use_anyevent};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;

        my ($old_val) = $self->{use_anyevent};
        $self->{use_anyevent} = $val;

        # Trigger
        $self->_set_anyevent( $val, $old_val );

        return $val;
    } else {
        confess("Invalid call");
    }
}


# XXX: Add validation that _cv is a Maybe[AnyEvent::CondVar]
sub _cv {
    if ( $#_ == 0 ) {
        return shift->{_cv};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_cv} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _last_error is a Maybe[Str]
sub _last_error {
    if ( $#_ == 0 ) {
        return shift->{_last_error};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_last_error} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _ordered_count is a non-negative integer
sub _ordered_count {
    if ( $#_ == 0 ) {
        my $self = shift;

        # Initialize
        if ( !exists( $self->{_ordered_count} ) ) { $self->{_ordered_count} = 0; }

        return $self->{_ordered_count};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_ordered_count} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _ordered_responses is an ArrayRef
sub _ordered_responses {
    if ( $#_ == 0 ) {
        my $self = shift;

        # Initialize
        if ( !exists( $self->{_ordered_responses} ) ) { $self->{_ordered_responses} = []; }

        return $self->{_ordered_responses};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_ordered_responses} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}


sub max_children {
    if ( $#_ == 0 ) {
        my $self = shift;

        if ( !exists( $self->{max_children} ) ) { $self->{max_children} = 5; }

        return $self->{max_children};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;

        # Validate
        if ( defined($val) ) {
            if ( $val !~ m/^[0-9]+$/s ) {
                confess("max_children must be set to a positive integer");
            }
            if ( $val <= 0 ) {
                confess("max_children must be set to a positive integer");
            }
        }

        $self->{max_children} = $val;

        # Trigger
        $self->_start_queued_children();

        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _subprocs is a HashRef
sub _subprocs {
    if ( $#_ == 0 ) {
        my $self = shift;

        # Initial value
        if ( !exists( $self->{_subprocs} ) ) { $self->{_subprocs} = {}; }

        return $self->{_subprocs};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_subprocs} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _count is a positive integer
# This only gets used on Win32.
sub _count {
    if ( $#_ == 0 ) {
        my $self = shift;

        # Initial value
        if ( !exists( $self->{_count} ) ) { $self->{_count} = 1; }

        return $self->{_count};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_count} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# XXX: Add validation that _parent_pid is a positive integer
# We also need to initialize always in the parent process.
sub _parent_pid {
    if ( $#_ == 0 ) {
        return shift->{_parent_pid};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_parent_pid} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}

# Children queued
# XXX: Add validation that _queued_cildren is an
# ArrayRef[ArrayRef[CodeRef]]
sub _queued_children {
    if ( $#_ == 0 ) {
        my $self = shift;

        if ( !exists( $self->{_queued_children} ) ) { $self->{_queued_children} = []; }

        return $self->{_queued_children};
    } elsif ( $#_ == 1 ) {
        my ( $self, $val ) = @_;
        $self->{_queued_children} = $val;
        return $val;
    } else {
        confess("Invalid call");
    }
}


sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    # Initialize parent PID
    $self->_parent_pid($$);

    # Make a weak reference and shove it into the ALL_WU array
    my $weakself = $self;
    weaken $weakself;
    push @ALL_WU, \$weakself;

    # Do some housekeeping on @ALL_WU, so it is somewhat bounded
    @ALL_WU = grep { defined $$_ } @ALL_WU;

    # Do we have any arguments?
    if (scalar(@_) > 0) {
        my %args = (scalar(@_) == 1) ? %{shift()} : @_;

        if (exists $args{use_anyevent}) {
            $self->use_anyevent($args{use_anyevent});
        }
        if (exists $args{max_children}) {
            $self->max_children($args{max_children});
        }
    }

    return $self;
}


sub async {
    if ( $#_ < 1 ) { confess 'invalid call'; }
    my $self = shift;
    my $sub  = shift;

    # Test $sub to make sure it is a code ref or a sub ref
    if ( !_codelike($sub) ) {
        confess("Parameter to async() is not a code (or codelike) reference");
    }

    my $callback;
    if ( scalar(@_) == 0 ) {
        # No callback provided

        my $cbnum = $self->_ordered_count;
        $self->_ordered_count( $cbnum + 1 );

        # We create a callback that populates the ordered responses
        my $selfref = $self;
        weaken $selfref;
        $callback = sub {
            if ( defined $selfref ) {    # In case this went away
                @{ $selfref->_ordered_responses }[$cbnum] = shift;
            }
        };
    } elsif ( scalar(@_) == 1 ) {
        # Callback provided
        $callback = shift;
    } else {
        confess 'invalid call';
    }

    # If there are pending errors, throw that.
    if ( defined( $self->_last_error ) ) { die( $self->_last_error ); }

    my $pipe = [ pipely() ];

    my $pid = fork();

    if ($pid) {
        # We are in the parent process

        $pipe = $pipe->[0];

        $self->_subprocs()->{$pid} = {
            fh       => $pipe,
            watcher  => undef,
            callback => $callback,
            caller   => [ caller() ],
        };

        # Set up anyevent listener if appropriate
        if ( $self->use_anyevent() ) {
            $self->_add_anyevent_watcher($pid);
        }

        return $pid;

    } else {
        # We are in the child process
        $pipe = $pipe->[1];

        return $self->_child( $sub, $pipe );
    }
}


sub asyncs {
    if ( $#_ < 2 ) { confess 'invalid call'; }
    my $self     = shift;
    my $children = shift;
    my $sub      = shift;
    if ( scalar(@_) > 1 ) { confess("invalid call"); }

    if ( $children !~ m/^[1-9][0-9]*$/s ) {
        confess("Number of children must be a numeric value > 0");
    }

    for ( my $i = 0; $i < $children; $i++ ) {
        $self->async( sub { return $sub->($i); }, @_ );
    }

    return $children;
}

sub _child {
    if ( scalar(@_) != 3 ) { confess 'invalid call'; }
    my ( $self, $sub, $pipe ) = @_;

    # Cleanup ALL_WU
    @ALL_WU = grep { defined $$_ } @ALL_WU;
    foreach my $wu ( map { $$_ } @ALL_WU ) {
        $wu->_clear_all();
    }

    try {
        my $result = $sub->();
        $self->_send_result( $pipe, $result );
    } catch {
        $self->_send_error( $pipe, $_ );
    };

    exit();
}


sub waitall {
    if ( $#_ != 0 ) { confess 'invalid call'; }
    my ($self) = @_;

    # No subprocs?  Just return.
    if ( scalar( keys %{ $self->_subprocs } ) == 0 ) {
        if ( $self->use_anyevent ) {
            $self->_cv( AnyEvent->condvar );
        }

        return $self->_get_and_reset_ordered_responses();
    }

    # Using cv?
    if ( defined( $self->_cv ) ) {
        $self->_cv->recv();
        if ( defined( $self->_last_error ) ) {
            my $err = $self->_last_error;
            $self->_last_error(undef);

            die($err);
        }

        return $self->_get_and_reset_ordered_responses();
    }

    # Tail recursion
    if ( $self->_waitone() ) { goto &waitall }

    return @{ $self->_get_and_reset_ordered_responses() };
}

# Gets the _ordered_responses and returns the reference.  Also
# resets the _ordered_responses and the _ordered_counts to an
# empty list and zero respectively.
sub _get_and_reset_ordered_responses {
    if ( $#_ != 0 ) { confess 'invalid call'; }
    my $self = shift;

    my (@r) = @{ $self->_ordered_responses() };

    $self->_ordered_responses( [] );
    $self->_ordered_count(0);

    return @r;
}


sub waitone {
    if ( $#_ != 0 ) { confess 'invalid call'; }
    my ($self) = @_;

    my $rv = $self->_waitone();

    # Using AnyEvent?
    if ( defined( $self->_last_error ) ) {
        my $err = $self->_last_error;
        $self->_last_error(undef);

        die($err);
    }

    return $rv;
}

# Meat of waitone (but doesn't handle returning an exception when using
# anyevent)
sub _waitone {
    if ( $#_ != 0 ) { confess 'invalid call'; }
    my ($self) = @_;

    my $sp = $self->_subprocs();
    weaken $sp;    # To avoid some Windows warnings
    if ( !keys(%$sp) ) { return; }

    # On everything but Windows
    #
    my $s = IO::Select->new();
    foreach ( keys(%$sp) ) { $s->add( $sp->{$_}{fh} ); }

    my @ready = $s->can_read();

    foreach my $fh (@ready) {
        foreach my $child ( keys(%$sp) ) {
            if ( defined( $fh->fileno() ) ) {
                if ( $fh->fileno() == $sp->{$child}{fh}->fileno() ) {
                    $self->_read_result($child);

                    waitpid( $child, 0 );

                    # Start queued children, if needed
                    $self->_start_queued_children();

                    return 1;    # We don't want to read more than one!
                }
            }
        }
    }

    # We should never get here
    return;
}


## no critic ('Subroutines::ProhibitBuiltinHomonyms')
sub wait {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my ( $self, $pid ) = @_;

    my $rv = $self->_wait($pid);

    if ( defined( $self->_last_error ) ) {
        my $err = $self->_last_error;
        $self->_last_error(undef);

        die($err);
    }

    return $rv;
}

# Internal version that doesn't check for AnyEvent die needs
sub _wait {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my ( $self, $pid ) = @_;

    if ( !exists( $self->_subprocs()->{$pid} ) ) {

        # We don't warn/die because it's possible that there is
        # a race between callback and here, in the main thread.
        return;
    }

    my $result = $self->_read_result($pid);

    waitpid( $pid, 0 );

    return $result;
}
## use critic


sub count {
    if ( $#_ != 0 ) { confess 'invalid call'; }
    my ($self) = @_;

    my $sp = $self->_subprocs();
    return scalar( keys %$sp );
}


sub queue {
    if ( $#_ < 1 ) { confess 'invalid call'; }
    my $self = shift;
    my $sub  = shift;

    # Test $sub to make sure it is a code ref or a sub ref
    if ( !_codelike($sub) ) {
        confess("Parameter to queue() is not a code (or codelike) reference");
    }

    my $callback;
    if ( scalar(@_) == 0 ) {
        # We're okay, don't need to do anything - no callback
    } elsif ( scalar(@_) == 1 ) {
        # We have a callback
        $callback = shift;
    } else {
        confess 'invalid call';
    }

    # If there are pending errors, throw that.
    if ( defined( $self->_last_error ) ) { die( $self->_last_error ); }

    push @{ $self->_queued_children }, [ $sub, $callback ];
    return $self->_start_queued_children();
}


sub queueall {
    if ( $#_ < 2 ) { confess 'invalid call'; }
    my $self = shift;
    my $data = shift;
    my $sub  = shift;

    for my $ele (@$data) {
        if (scalar(@_) > 0) {
            $self->queue(sub { $sub->($ele) }, @_);
        } else {
            $self->queue(sub { $sub->($ele) });
        }
    }
    return 1;
}

sub _send_result {
    if ( $#_ != 2 ) { confess 'invalid call'; }
    my ( $self, $fh, $msg ) = @_;

    return $self->_send( $fh, 'RESULT', $msg );
}

sub _send_error {
    if ( $#_ != 2 ) { confess 'invalid call'; }
    my ( $self, $fh, $err ) = @_;

    return $self->_send( $fh, 'ERROR', $err );
}

sub _send {
    if ( $#_ != 3 ) { confess 'invalid call'; }
    my ( $self, $fh, $type, $data ) = @_;

    my $msg;
    if ( blessed($data) && ($data->can('FREEZE')) && ($data->can('THAW')) ) {
        $msg = ref($data) . "!::!" . $data->FREEZE();
    } else {
        $msg = "!::!" . Storable::freeze( \$data );
    }

    if ( !defined($msg) ) {
        die 'freeze() returned undef for child return value';
    }

    $fh->write($type);
    $fh->write("\n");

    $fh->write( length($msg) );
    $fh->write("\n");

    binmode( $fh, ':raw' );

    $fh->write($msg);

    $fh->close();
    return;
}

sub _read_result {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my ( $self, $child ) = @_;

    my $cinfo = $self->_subprocs()->{$child};
    if (defined($cinfo->{rawbuff})) {
        return $self->_read_result_from_buffer($child);
    } else {
        return $self->_read_result_from_fh($child);
    }
}

sub _read_result_from_buffer {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my ( $self, $child ) = @_;

    my $cinfo = $self->_subprocs()->{$child};
    $cinfo->{fh}->close();

    my ($type, $size, $buffer) = split /\n/, $cinfo->{rawbuff}, 3;
    delete $cinfo->{rawbuff};

    if ( !defined($type) ) { die 'Could not read child data'; }
    if ( !defined($size) ) { die 'Could not read child data'; }

    my ($class, $frozen) = split("!::!", $buffer, 2);
    my $data;
    if ($class eq "") {
        $data = ${ Storable::thaw($frozen) };
    } else {
        $data = $class->THAW($frozen);
    }


    my $caller = $self->_subprocs()->{$child}{caller};
    delete $self->_subprocs()->{$child};

    if ( $type eq 'RESULT' ) {
        $cinfo->{callback}->($data);
    } else {
        my $err =
            "Child (created at "
          . $caller->[1]
          . " line "
          . $caller->[2]
          . ") died with error: $data";

        if ( $self->use_anyevent ) {
            # Can't throw events with anyevent
            $self->_last_error($err);
        } else {
            # Otherwise we do throw it
            die($err);
        }
    }

    return;
}

sub _read_result_from_fh {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my ( $self, $child ) = @_;

    my $cinfo = $self->_subprocs()->{$child};
    my $fh    = $cinfo->{fh};

    my $type = <$fh>;
    if ( !defined($type) ) { die 'Could not read child data'; }
    chomp($type);

    my $size = <$fh>;
    chomp($size);

    binmode($fh);

    my $result = '';

    my $ret = 1;
    while ( defined($ret) && ( length($result) < $size ) ) {
        my $s = $size - length($result);

        my $part = '';
        $ret = $fh->read( $part, $s );
        if ( defined($ret) ) { $result .= $part; }
    }

    my ($class, $frozen) = split("!::!", $result, 2);
    my $data;
    if ($class eq "") {
        $data = ${ Storable::thaw($frozen) };
    } else {
        $data = $class->THAW($frozen);
    }

    my $caller = $self->_subprocs()->{$child}{caller};
    delete $self->_subprocs()->{$child};
    $fh->close();

    if ( $type eq 'RESULT' ) {
        $cinfo->{callback}->($data);
    } else {
        my $err =
            "Child (created at "
          . $caller->[1]
          . " line "
          . $caller->[2]
          . ") died with error: $data";

        if ( $self->use_anyevent ) {
            # Can't throw events with anyevent
            $self->_last_error($err);
        } else {
            # Otherwise we do throw it
            die($err);
        }
    }

    return;
}

# Start queued children, if possible.
# Returns 1 if children were started, undef otherwise
sub _start_queued_children {
    if ( $#_ != 0 ) { confess 'invalid call' }
    my ($self) = @_;

    if ( !( @{ $self->_queued_children } ) ) { return; }
    if ( defined( $self->_last_error ) )     { return; }    # Do not queue if there are errors

    # Can we start a queued process?
    while ( scalar @{ $self->_queued_children } ) {
        if ( ( !defined( $self->max_children ) ) || ( $self->count < $self->max_children ) ) {
            # Start queued child
            my $ele = shift @{ $self->_queued_children };
            if ( !defined( $ele->[1] ) ) {
                $self->async( $ele->[0] );
            } else {
                $self->async( $ele->[0], $ele->[1] );
            }
        } else {
            # Can't unqueue
            return;
        }
    }

    # We started at least one process
    return 1;
}

# Sets up AnyEvent or tears it down as needed
sub _set_anyevent {
    if ( $#_ < 1 ) { confess 'invalid call' }
    if ( $#_ > 2 ) { confess 'invalid call' }
    my ( $self, $new, $old ) = @_;

    if ( ( !$old ) && $new ) {
        # We are setting up AnyEvent
        require AnyEvent;

        if ( defined( $self->_subprocs() ) ) {
            foreach my $pid ( keys %{ $self->_subprocs() } ) {
                $self->_add_anyevent_watcher($pid);
            }
        }

        $self->_cv( AnyEvent->condvar );

    } elsif ( $old && ( !$new ) ) {
        # We are tearing down AnyEvent

        if ( defined( $self->_subprocs() ) ) {
            foreach my $pid ( keys %{ $self->_subprocs() } ) {
                my $proc = $self->_subprocs()->{$pid};

                $proc->{watcher} = undef;
            }
        }

        $self->_cv(undef);
    }
    return;
}

# Sets up the listener for AnyEvent
sub _add_anyevent_watcher {
    if ( $#_ != 1 ) { confess 'invalid call' }
    my ( $self, $pid ) = @_;

    my $proc = $self->_subprocs()->{$pid};

    $proc->{watcher} = AnyEvent->io(
        fh   => $proc->{fh},
        poll => 'r',
        cb   => sub {
            $self->_wait($pid);
            if ( scalar( keys %{ $self->_subprocs() } ) == 0 ) {
                my $oldcv = $self->_cv;
                $self->_cv( AnyEvent->condvar );
                $oldcv->send();
            }

            # Start queued children, if needed
            $self->_start_queued_children();
        },
    );

    return;
}

# Used to clear all sub-processes, etc, in child process.
sub _clear_all {
    if ( $#_ != 0 ) { confess 'invalid call' }
    my ( $self ) = @_;

    $self->_cv(undef);
    $self->_last_error(undef);
    $self->_ordered_count(0);
    $self->_ordered_responses( [] );
    $self->_count(1);
    $self->_queued_children( [] );

    do {
        # Don't warn on AnyEvent in child threads being DESTROYed
        local $SIG{__WARN__} = sub { };
        $self->_subprocs( {} );
    };

    return;
}


sub start {
    if ( $#_ != 1 ) { confess 'invalid call'; }
    my $self = shift;
    my $sub  = shift;

    # Test $sub to make sure it is a code ref or a sub ref
    if ( !_codelike($sub) ) {
        confess("Parameter to start() is not a code (or codelike) reference");
    }

    my $pid = fork();

    if ( !$pid ) {
        # We are in the child process.
        $sub->();
        exit();
    }

    return;
}

# Tests to see if something is codelike
#
# Borrowed from Params::Util (written by Adam Kennedy)
sub _codelike {
    if ( scalar(@_) != 1 ) { confess 'invalid call' }
    my $thing = shift;

    if ( reftype($thing) ) { return 1; }
    if ( blessed($thing) && overload::Method( $thing, '()' ) ) { return 1; }

    return;
}

# Destructor emits warning if sub processes are running
sub DESTROY {
    my $self = shift;

    if ( scalar( keys %{ $self->_subprocs } ) ) {
        warn "Warning: Subprocesses running when Parallel::WorkUnit object destroyed\n";
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Parallel::WorkUnit - Provide multi-paradigm forking with ability to pass back data

=head1 VERSION

version 2.243480

=head1 SYNOPSIS

  #
  # Standard Interface
  #
  my $wu = Parallel::WorkUnit->new();
  $wu->async( sub { ... }, \&callback );

  $wu->waitall();


  #
  # Limiting Maximum Parallelization
  #
  $wu->max_children(5);
  $wu->queue( sub { ... }, \&callback );
  $wu->queueall( \@data, sub { ... }, \&callback );
  $wu->waitall();


  #
  # Ordered Responses
  #
  my $wu = Parallel::WorkUnit->new();
  $wu->async( sub { ... } );

  @results = $wu->waitall();

  #
  # Spawning off X number of workers
  # (Ordered Response paradigm shown with 10 children)
  #
  my $wu = Parallel::WorkUnit->new();
  $wu->asyncs( 10, sub { ... } );

  @results = $wu->waitall();


  #
  # AnyEvent Interface (only usable if AnyEvent is installed)
  #
  use AnyEvent;
  my $wu = Parallel::WorkUnit->new();

  $wu->use_anyevent(1);
  $wu->async( sub { ... }, \&callback );
  $wu->waitall();  # Not strictly necessary, callbacks happen within event loop


  #
  # Just spawn something into another process, don't capture return
  # values, don't allow waiting on process, etc.
  #
  my $wu = Parallel::Workunit->new();
  $wu->start( { ... } );

=head1 DESCRIPTION

This is a very simple forking implementation of parallelism, with the
ability to pass data back from the asyncronous child process in a
relatively efficient way (with the limitation of using a pipe to pass
the information, serialized, back).  It was designed to be very simple
for a developer to use, with the ability to pass reasonably large amounts
of data back to the parent process.

This module is also designed to work with AnyEvent when desired, but it
does not require AnyEvent to be installed for other functionality to work.

There are many other Parallel::* applications in CPAN - it would be worth
any developer's time to look through those and choose the best one.

=head1 ATTRIBUTES

=head2 use_anyevent

  $wu->use_anyevent(1);

If set to a value that is true, creates AnyEvent watchers for each
asyncronous or queued job.  The equivilent of an C<AnyEvent> condition
variable C<recv()>, used when all processes finish executing, is the
C<waitall()> method.  However, the processes are integrated into a
standard C<AnyEvent> loop, so it isn't strictly necessary to call C<waitall()>.
In addition, a call to C<waitall()> will execute other processes in
the C<AnyEvent> event loop.

The default value is false.

=head2 max_children

  $wu->max_children(5);
  $wu->max_children(undef);

  say "Max number of children: " . $wu->max_children();

If set to a value other than zero or undef, limits the number of outstanding
queue children (created by the C<queue()> or C<queueall()> method) that can be
executing at any given time.

This defaults to 5.

This attribute does not impact the C<async()> method's ability to
create children, but these children will count against the limit used
by C<queue()> or C<queueall()>.

Calling without any parameters will return the number of children.

=head1 METHODS

=head2 new

Create a new workunit class.  Optionally, takes a list that corresponds
to a hashref, in the form of key and value.  This accepts the key
C<max_children>, which, if present (and not undef) will limit the
number of spawned subprocesses that can be active when using the
C<queue()> or C<queueall()> methods.  Defaults to 5.  See the C<max_children>
method for additional information.

=head2 async( sub { ... }, \&callback )

  $wu->async( sub { return 1 }, \&callback );

  # To get back results in "ordered" return mode
  $wu->async( sub { return 1 } );
  @results = $wu->waitall();

Spawns work on a new forked process.  The forked process inherits
all Perl state from the parent process, as would be expected with
a standard C<fork()> call.  The child shares nothing with the
parent, other than the return value of the work done.

The work is specified either as a subroutine reference or an
anonymous sub (C<sub { ... }>) and should return a scalar.  Any
scalar that L<Storable>'s C<freeze()> method can deal with
is acceptable (for instance, a hash reference or C<undef>).

The result is serialized and streamed back to the parent process
via a pipe.  The parent, in a C<waitall()> call, will call the
callback function (if provided) with the unserialized return value.

If a callback is not provided, the parent, in the C<waitall()> call,
will gather these results and return them as an ordered list.

In all modes, should the child process C<die>, the parent process
will also die (inside the C<waitall()> method).

The PID of the child is returned to the parent process when
this method is executed.

The C<max_children> attribute is not examined in this method - you
can spawn a new child regardless of the number of children already
spawned. However, you children started with this method still count
against the limit used by C<queue()> or C<queueall()>.

=head2 asyncs( $children, sub { ... }, \&callback )

  $wu->asyncs( 10, sub { return 1 }, \&callback );

  # To get back results in "ordered" return mode
  $wu->asyncs( 10, sub { return 1 } );
  @results = $wu->waitall();

Added in 1.117.

This functions similarly to the C<async()> method, with a couple
key differences.

First, it takes an additional parameter, C<$children>, that specifies
the number of child processes to spawn.  Like the C<async()> method,
the children are spawned immediately, regardless of the value of
the C<max_children> attribute.

In addition, when the sub/coderef is executed, it is called with a
single parameter representing the child number in that particular
instance (between zero to C<$children-1>).

Returns the number of children spawned.

See C<async()> for more details on how this function works.

=head2 waitall()

Called from the parent method while waiting for the children
to exit.  This method handles children that C<die()> or return
a serializable data structure.  When all children return, this
method will return.

If a child dies unexpectedly, this method will C<die()> and propagate a
modified exception.

In the standard (not ordered) mode, I.E. where a callback was passed
to C<async()>, this will return nothing.

In the ordered mode, I.E. where no callbacks were provided to C<async()>,
this will return the results of the async calls in an ordered list.  The
list will be ordered by the order in which the async calls were executed.

=head2 waitone()

This method similarly to C<waitall()>, but only waits for
a single PID.  It will return after any PID exits.

If this method is called when there is no processes executing,
it will simply return undef. Otherwise, it will wait and then
return 1.

=head2 wait($pid)

This functions simiarly to C<waitone()>, but waits only for
a specific PID.  See the C<waitone()> documentation above
for details.

If C<wait()> is called on a process that is already done
executing, it simply returns.  Otherwise, it waits until the
child process's work unit is complete and executes the callback
routine, then returns.

=head2 count()

This method returns the number of currently outstanding
processes (in either a running state or a waiting to send their
output).

=head2 queue( sub { ... }, \&callback )

Spawns work on a new forked process, doing so immediately if less
than C<max_children> are running.  If there are already
C<max_children> are running, this will run the process once a slot
becomes available.

This method should be treated as nearly identical to C<async()>,
with the only difference being the above behavior (limiting to
C<max_children>) and not returning a PID.  Instead, a value of 1
is returned if the process is immediately started, C<undef>
otherwise.

The result is serialized and streamed back to the parent process
via a pipe.  The parent, in a C<waitall()> call, will call the
callback function (if provided) with the unserialized return value.

If a callback is not provided, the parent, in the C<waitall()> call,
will gather these results and return them as an ordered list.

=head2 queueall( $data, sub { ... }, \&callback )

Added in 2.243450.

The C<$data> paraemter should be a reference to a list.

Spawns work on a new forked process, for each element in C<@$data>,
doing so immediately if less than C<max_children> are running.  If there
are already C<max_children> are running, this will run the process once
a slot becomes available.

This method should be treated as nearly identical to C<queue()>, if
C<queue()> was called within a for loop, and the work subroutine took
one paramenter (the element of the data to operate on).

The result is serialized and streamed back to the parent process
via a pipe.  The parent, in a C<waitall()> call, will call the
callback function (if provided) with the unserialized return value.

If a callback is not provided, the parent, in the C<waitall()> call,
will gather these results and return them as an ordered list.

This always returns 1 on enqueuing the processes.

=head2 start( sub { ... } );

Added in 1.191810.

Spawns work on a new forked process, doing so immediately regardless of how
many other children are running.

This method is similar to C<async()>, but unlike C<async()>, no provision to
receive return value or wait on the child is made.  This is somewhat similar
to C<start> in Raku (but differs as this starts a subprocess, not a new
thread, and there is thus no shared data (changes to data in the child process
will not be seen in the parent process).

Note that the child inherits all open file descriptors.

Not also that the child process will be part of the same process group as the
parent process.  Additional work is required to daemonize the child.

=head1 CAVEATS

This module uses L<Storable> to serialize objects, except for objects
that have a C<FREEZE> and C<THAW> method defined, in which case those
methods are used.  As a result, it cannot serialize some objects, such
as C<REGEXP> (sometimes), C<CODE>, or C<OBJECT> (I.E. Corinna objects
created with the C<class> statement in Perl 5.38+), unless these
objects also have a C<FREEZE> and C<THAW> method defined.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015-2024 by Joelle Maslak.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
