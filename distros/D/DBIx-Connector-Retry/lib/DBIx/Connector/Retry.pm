package DBIx::Connector::Retry;

our $AUTHORITY = 'cpan:GSG';
# ABSTRACT: DBIx::Connector with block retry support
use version;
our $VERSION = 'v0.900.3'; # VERSION

use strict;
use warnings;

use Moo;

extends 'DBIx::Connector', 'Moo::Object';

use Scalar::Util           qw( weaken );
use Types::Standard        qw( Str Bool HashRef CodeRef Dict Tuple Optional Maybe );
use Types::Common::Numeric qw( PositiveInt );

use namespace::clean;  # don't export the above

#pod =encoding utf8
#pod
#pod =head1 SYNOPSIS
#pod
#pod     my $conn = DBIx::Connector::Retry->new(
#pod         connect_info  => [ 'dbi:Driver:database=foobar', $user, $pass, \%args ],
#pod         retry_debug   => 1,
#pod         max_attempts  => 5,
#pod     );
#pod
#pod     # Keep retrying/reconnecting on errors
#pod     my ($count) = $conn->run(ping => sub {
#pod         $_->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');
#pod         $_->selectrow_array('SELECT COUNT(*) FROM foobar WHERE updated = 1');
#pod     });
#pod
#pod     # Add a simple retry_handler for a manual timeout
#pod     my $start_time = time;
#pod     $conn->retry_handler(sub { time <= $start_time + 60 });
#pod
#pod     my ($count) = $conn->txn(fixup => sub {
#pod         $_->selectrow_array('SELECT COUNT(*) FROM barbaz');
#pod     });
#pod     $conn->clear_retry_handler;
#pod
#pod     # Plus everything else in DBIx::Connector
#pod
#pod =head1 DESCRIPTION
#pod
#pod DBIx::Connector::Retry is a Moo-based subclass of L<DBIx::Connector> that will retry on
#pod failures.  Most of the interface was modeled after L<DBIx::Class::Storage::BlockRunner>
#pod and adapted for use in DBIx::Connector.
#pod
#pod =head1 ATTRIBUTES
#pod
#pod =head2 connect_info
#pod
#pod An arrayref that contains all of the connection details normally found in the L<DBI> or
#pod L<DBIx::Connector> call.  This data can be changed, but won't take effect until the next
#pod C<$dbh> re-connection cycle.
#pod
#pod Obviously, this is required.
#pod
#pod =cut

has connect_info => (
    is       => 'rw',
    # Yes, DBI->connect() is still technically-valid syntax
    isa      => Tuple[ Maybe[Str], Maybe[Str], Maybe[Str], Optional[HashRef] ],
    required => 1,
);

#pod =head2 mode
#pod
#pod This is just like L<DBIx::Connector/mode> except that it can be set from within the
#pod constructor.
#pod
#pod Unlike DBIx::Connector, the default is C<ping>, not C<no_ping>.
#pod
#pod =cut

has _mode => (
    is       => 'bare',  # use DBIx::Connector's accessor
    isa      => Str,
    init_arg => 'mode',
    required => 0,
    default  => 'ping',
);

#pod =head2 disconnect_on_destroy
#pod
#pod This is just like L<DBIx::Connector/disconnect_on_destroy> except that it can be set
#pod from within the constructor.
#pod
#pod Default is on.
#pod
#pod =cut

has _dond => (
    is       => 'bare',  # use DBIx::Connector's accessor
    isa      => Bool,
    init_arg => 'disconnect_on_destroy',
    required => 0,
    default  => 1,
);

#pod =head2 max_attempts
#pod
#pod The maximum amount of block running attempts before the Connector gives up and dies.
#pod
#pod Default is 10.
#pod
#pod =cut

has max_attempts => (
    is       => 'rw',
    isa      => PositiveInt,
    required => 0,
    default  => 10,
);

#pod =head2 retry_debug
#pod
#pod If enabled, any retries will output a debug warning with the error message and number
#pod of retries.
#pod
#pod =cut

has retry_debug => (
    is       => 'rw',
    isa      => Bool,
    required => 0,
    default  => 0,
    lazy     => 1,
);

sub _warn_retry_debug {
    my $self = shift;

    my $current_attempt_count = $self->failed_attempt_count + 1;

    warn sprintf(
        'Retrying %s coderef (attempt %d) after caught exception: %s',
        $self->execute_method, $current_attempt_count, $self->last_exception
    );
}

#pod =head2 retry_handler
#pod
#pod An optional handler that will be checked on each retry.  It will be passed the Connector
#pod object as its only input.  If the handler returns a true value, retries will continue.
#pod A false value will cause the retry loop to immediately rethrow the exception.  You can
#pod also throw your own, if you prefer.
#pod
#pod This check is independent of checks for L</max_attempts>.
#pod
#pod The last exception can be inspected as part of the check by looking at L</last_exception>.
#pod This is recommended to make sure the failure is actually what you expect it to be.
#pod For example:
#pod
#pod     $conn->retry_handler(sub {
#pod         my $c = shift;
#pod         my $err = $c->last_exception;
#pod         $err = $err->error if blessed $err && $err->isa('DBIx::Connector::RollbackError');
#pod
#pod         # only retry on deadlocks or timeouts (only look in the first line
#pod         # of the error to avoid e.g. accidental matches in a stack trace)
#pod         $err =~ /^\V*(?:deadlock|timeout)/i;
#pod     });
#pod
#pod Default is an always-true coderef.
#pod
#pod This attribute has the following handles:
#pod
#pod =head3 clear_retry_handler
#pod
#pod Sets it back to the always-true default.
#pod
#pod =cut

has retry_handler => (
    is       => 'rw',
    isa      => CodeRef,
    required => 1,
    default  => sub { sub { 1 } },
);

sub clear_retry_handler { shift->retry_handler(sub { 1 }) }

#pod =head2 execute_method
#pod
#pod The current L<DBIx::Connector> execution method name being called, which would either be
#pod C<run> or C<txn>.  Since C<svp> is not overridden, it would never be encountered.  If the
#pod connector is not in the middle of DB block execution, this attribute is blank.
#pod
#pod =cut

has execute_method => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    writer   => '_set_execute_method',
    default  => '',
);

#pod =head2 failed_attempt_count
#pod
#pod The number of failed attempts so far.  This can be used in the L</retry_handler> or
#pod checked afterwards.  It will be reset on each block run.
#pod
#pod Not available for initialization.
#pod
#pod =cut

has failed_attempt_count => (
    is       => 'ro',
    init_arg => undef,
    writer   => '_set_failed_attempt_count',
    default  => 0,
    lazy     => 1,
    trigger  => sub {
        my ($self, $val) = @_;
        $self->_die_from_max_attempts if $self->max_attempts <= ( $val || 0 );
    },
);

sub _die_from_max_attempts {
    my $self = shift;
    die sprintf (
        'Reached max_attempts amount of %d, latest exception: %s',
        $self->max_attempts, $self->last_exception
    );
}

#pod =head2 exception_stack
#pod
#pod The stack of exceptions received so far, as an arrayref.  This can be used in the
#pod L</retry_handler> or checked afterwards.  It will be reset on each block run.
#pod
#pod Not available for initialization.
#pod
#pod This attribute has the following handles:
#pod
#pod =head3 last_exception
#pod
#pod The last exception on the stack.
#pod
#pod =cut

has exception_stack => (
    is       => 'ro',
    init_arg => undef,
    clearer  => '_reset_exception_stack',
    default  => sub { [] },
    lazy     => 1,
);

sub last_exception { shift->exception_stack->[-1] }

#pod =head1 CONSTRUCTORS
#pod
#pod =head2 new
#pod
#pod     my $conn = DBIx::Connector::Retry->new(
#pod         connect_info => [ 'dbi:Driver:database=foobar', $user, $pass, \%args ],
#pod         max_attempts => 5,
#pod         # ...etc...
#pod     );
#pod
#pod     # Old-DBI syntax
#pod     my $conn = DBIx::Connector::Retry->new(
#pod         'dbi:Driver:database=foobar', $user, $pass, \%dbi_args,
#pod         max_attempts => 5,
#pod         # ...etc...
#pod     );
#pod
#pod As this is a L<Moo> class, it uses the standard Moo constructor.  The L</connect_info>
#pod should be specified as its own key.  The L<DBI>/L<DBIx::Connector> syntax is available,
#pod but only as a nicety for compatibility.
#pod
#pod =cut

around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;

    # Old-style DBI/DBIx::Connector parameters.  Try to fix it up.
    if (@args && $args[0] && !ref $args[0] && $args[0] =~ /^dbi:/) {
        my @connect_info = splice(@args, 0, 3);                                       # DBI DSN, UN, PW
        push @connect_info, shift @args if $args[0] && (ref $args[0]||'') eq 'HASH';  # DBI \%attr, if it exists

        if ( @args && $args[0] && (my $ref = ref $args[0]) ) {
            if    ($ref eq 'ARRAY') {
                push @{$args[0]}, ( connect_info => \@connect_info );
                @args = @{$args[0]};  # Moo::Object::BUILDARGS doesn't actually support lone ARRAYREFs
            }
            elsif ($ref eq 'HASH') {
                $args[0]{connect_info} = \@connect_info;
            }
            else {
                # Mimicing Moo::Object::BUILDARGS here
                Carp::croak(join ' ',
                    "The new() method for $class cannot parse the strange argument list.",
                    "Please switch to a standard Moo constructor, instead of the DBI syntax.",
                );
            }
        }
        else {
            # either the key within a list or we're out of arguments
            push @args, ( connect_info => \@connect_info );
        }
    }

    return $class->$orig(@args);
};

sub BUILD {
    my ($self, $args) = @_;

    my @connect_args = @{ $self->connect_info };

    # Add in the keys that DBIx::Connector expects.  For the purposes of future
    # expandability of DBIx::Connector, we do this by getting a new base Connector
    # object, and inject those properties into our own object.

    my $base_obj = DBIx::Connector->new(@connect_args);
    %$self = (
        %$base_obj,
        %$self,  # $self's existing attributes take priority
    );

    # DBIx::Connector stores connection details in a coderef (for some reason).  Instead
    # of just dumping the same arguments as another copy, we'll tie it directly to the
    # attr.  If connect_info ever changes, it will grab the latest version.
    $self->{_args} = sub { @{ $self->connect_info } };
    weaken $self;  # circular closure ref
}

#pod =head1 MODIFIED METHODS
#pod
#pod =head2 run / txn
#pod
#pod     my @result = $conn->run($mode => $coderef);
#pod     my $result = $conn->run($mode => $coderef);
#pod     $conn->run($mode => $coderef);
#pod
#pod     my @result = $conn->txn($mode => $coderef);
#pod     my $result = $conn->txn($mode => $coderef);
#pod     $conn->txn($mode => $coderef);
#pod
#pod Both L<run|DBIx::Connector/run> and L<txn|DBIx::Connector/txn> are modified to run inside
#pod a retry loop.  If the original Connector action dies, the exception is caught, and if
#pod L</retry_handler> and L</max_attempts> allows it, the action is retried.  The database
#pod handle may be reset by the Connector action, according to its connection mode.
#pod
#pod See L</CAVEATS> for important behaviors/limitations.
#pod
#pod =cut

foreach my $method (qw< run txn >) {
    around $method => sub {
        my $orig = shift;
        my $self = shift;
        my $mode = ref $_[0] eq 'CODE' ? $self->{_mode} : shift;
        my $cref = shift;

        my $wantarray = wantarray;

        return $self->_retry_loop($orig, $method, $mode, $cref, $wantarray);
    };
}

sub _retry_loop {
    my ($self, $orig, $method, $mode, $cref, $wantarray) = @_;

    # For the purposes of nesting, these variables should be localized.
    local $self->{exception_stack}      = [];
    local $self->{failed_attempt_count} = 0;
    local $self->{execute_method}       = $method;

    # If we already started in a transaction, that implies nesting, so don't
    # retry the query.  We can't guarantee that the statements before the block
    # run will be committed, and are assuming that the connection will break.
    #
    # We cannot rely on checking the database connection via ping, because some
    # DBDs (like mysql) will try to reconnect to the DB if the first ping check
    # fails, and a reconnection auto-rollbacks all transactions, locks, etc.
    if ($self->in_txn) {
        unless (defined $wantarray) { return        $self->$orig($mode, $cref)  }
        elsif          ($wantarray) { return       ($self->$orig($mode, $cref)) }
        else                        { return scalar $self->$orig($mode, $cref)  }
    }

    # Mode is localized within $orig, but we should localize it again ourselves, in case
    # it's changed on-the-fly.
    local $self->{_mode} = $mode;

    my $run_err;
    my @res;

    do {
        TRY: {
            ### NOTE: Outside exception handlers shouldn't interrupt the retry process, as it might
            ### never return back from the eval.  However, if we need to die after the retry_handler
            ### check below, that should still go to whatever exception handler is in place.
            ### Therefore, this "local $SIG{__DIE__}" is exactly in this TRY block and expires after
            ### the DB error is captured.
            local $SIG{__DIE__};
            local $@;

            eval {
                unless (defined $wantarray) {           $self->$orig($mode, $cref) }
                elsif          ($wantarray) { @res    = $self->$orig($mode, $cref) }
                else                        { $res[0] = $self->$orig($mode, $cref) }
            };
            $run_err = $@;
        }

        if ($run_err) {
            push @{ $self->exception_stack }, $run_err;

            # This will throw if max_attempts is reached
            $self->_set_failed_attempt_count($self->failed_attempt_count + 1);

            # If the retry handler says no, then die
            die $run_err unless $self->retry_handler->($self);

            # Debug line
            $self->_warn_retry_debug if $self->retry_debug;
        }
    } while ($run_err);

    return $wantarray ? @res : $res[0];
}

#pod =head1 CAVEATS
#pod
#pod =head2 $dbh settings
#pod
#pod Like L<DBIx::Connector>, it's important that the L</connect_info> properties have sane
#pod connection settings.
#pod
#pod L<AutoCommit|DBI/AutoCommit> should be turned on.  Otherwise, the connection is
#pod considered to be already in a transaction, and no retries will be attempted.  Instead,
#pod use transactions via L<txn|DBIx::Connector/txn>.
#pod
#pod L<RaiseError|DBI/RaiseError> should also be turned on, since exceptions are captured,
#pod and both Retry and Connector use them to determine if any of the C<$dbh> calls failed.
#pod
#pod =head2 Savepoints and nested transactions
#pod
#pod L<The svp method|DBIx::Connector/svp> is NOT modified to work inside of a retry loop,
#pod because retries are generally not possible for savepoints, and a disconnected connection
#pod will rollback any uncommited statements in most RDBMS.  The same goes for any C<run>/C<txn>
#pod calls attempted inside of a transaction.
#pod
#pod Consider the following:
#pod
#pod     # If this dies, sub will retry
#pod     $conn->txn(ping => sub {
#pod         shift->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');
#pod
#pod         # If this dies, it will not retry
#pod         $conn->svp(sub {
#pod             my $c = shift;
#pod             $c->do('INSERT foobar (name, updated, active) VALUES (?, ?)', undef, 'barbaz', 0, 'off');
#pod         });
#pod     });
#pod
#pod If the savepoint actually tried to retry, the C<UPDATE> statement would get rolled back by
#pod virtue of database disconnection.  However, the savepoint code would continue, possibly
#pod even succeeding.  You would never know that the C<UPDATE> statement was rolled back.
#pod
#pod However, without savepoint retry support, as it is currently designed, the statements
#pod will work as expected.  If the savepoint code dies, and if C<$conn> is set up for
#pod retries, the transaction code is restarted, after a rollback or reconnection.  Thus, the
#pod C<UPDATE> and C<INSERT> statements are both ran properly if they now succeed.
#pod
#pod Obviously, this will not work if transactions are manually started outside of the main
#pod Connector interface:
#pod
#pod     # Don't do this!  The whole transaction isn't compartmentalized properly!
#pod     $conn->run(ping => sub {
#pod         $_->begin_work;  # don't ever call this!
#pod         $_->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');
#pod     });
#pod
#pod     # If this dies, the whole app will probably crash
#pod     $conn->svp(sub {
#pod         my $c = shift;
#pod         $c->do('INSERT foobar (name, updated, active) VALUES (?, ?)', undef, 'barbaz', 0, 'off');
#pod     });
#pod
#pod     # Don't do this!
#pod     $conn->run(ping => sub {
#pod         $_->commit;  # no, let Connector handle this process!
#pod     });
#pod
#pod =head2 (Ab)using $dbh directly
#pod
#pod For maximum retry protection, do not use the L<dbh|DBIx::Connector/dbh> or
#pod L<connect|DBIx::Connector/connect> methods directly.  Directly accessing and using a DBI
#pod database or statement handle does NOT grant retry protection, even if it was acquired
#pod from those methods.  Furthermore, using those methods may trigger a connection failure,
#pod which isn't protected by C<eval>.
#pod
#pod Instead, only use the C<run>/C<txn> methods, and it will attempt the connection for you.
#pod If the connection fails, retry protection kicks in, as it's part of the same retry loop.
#pod
#pod =head2 Fixup mode
#pod
#pod Because of the nature of L<fixup mode|DBIx::Connector/Connection Modes>, the block may be
#pod executed twice as often.  Functionally, the code looks like this:
#pod
#pod     # Very simplified example
#pod     sub fixup_run {
#pod         my ($self, $code) = @_;
#pod
#pod         my (@ret, $run_err);
#pod         do {
#pod             eval {
#pod                 @ret = eval { $code->($dbh) };
#pod                 my $err = $@;
#pod
#pod                 if ($err) {
#pod                     die $err if $self->connected;
#pod                     # Not connected. Try again.
#pod                     return $code->($dbh);
#pod                 }
#pod             };
#pod             $run_err = $@;
#pod
#pod             if ($run_err) {
#pod                 # Push exception_stack, set/check attempts, check retry_handler
#pod             }
#pod         } while ($run_err);
#pod         return @ret;
#pod     }
#pod
#pod If the first eval dies because of a connection failure, the code is ran twice before the
#pod retry loop finds it.  This is only considered to be one attempt.  If it dies because of
#pod some other fault, it's only ran once and continues the retry loop.
#pod
#pod If this is behavior is undesirable, this can be worked around by using the L</retry_handler>
#pod to change the L<mode|DBIx::Connector/mode> after the first attempt:
#pod
#pod     $conn->retry_handler(sub {
#pod         my $c = shift;
#pod         $c->mode('ping') if $c->mode eq 'fixup';
#pod         1;
#pod     });
#pod
#pod Mode is localized outside of the retry loop, so even C<< $conn->run(fixup => $code) >>
#pod calls work, and the default mode will return to normal after the block run.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<DBIx::Connector>, L<DBIx::Class>
#pod
#pod =cut

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::Connector::Retry - DBIx::Connector with block retry support

=head1 VERSION

version v0.900.3

=head1 SYNOPSIS

    my $conn = DBIx::Connector::Retry->new(
        connect_info  => [ 'dbi:Driver:database=foobar', $user, $pass, \%args ],
        retry_debug   => 1,
        max_attempts  => 5,
    );

    # Keep retrying/reconnecting on errors
    my ($count) = $conn->run(ping => sub {
        $_->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');
        $_->selectrow_array('SELECT COUNT(*) FROM foobar WHERE updated = 1');
    });

    # Add a simple retry_handler for a manual timeout
    my $start_time = time;
    $conn->retry_handler(sub { time <= $start_time + 60 });

    my ($count) = $conn->txn(fixup => sub {
        $_->selectrow_array('SELECT COUNT(*) FROM barbaz');
    });
    $conn->clear_retry_handler;

    # Plus everything else in DBIx::Connector

=head1 DESCRIPTION

DBIx::Connector::Retry is a Moo-based subclass of L<DBIx::Connector> that will retry on
failures.  Most of the interface was modeled after L<DBIx::Class::Storage::BlockRunner>
and adapted for use in DBIx::Connector.

=head1 ATTRIBUTES

=head2 connect_info

An arrayref that contains all of the connection details normally found in the L<DBI> or
L<DBIx::Connector> call.  This data can be changed, but won't take effect until the next
C<$dbh> re-connection cycle.

Obviously, this is required.

=head2 mode

This is just like L<DBIx::Connector/mode> except that it can be set from within the
constructor.

Unlike DBIx::Connector, the default is C<ping>, not C<no_ping>.

=head2 disconnect_on_destroy

This is just like L<DBIx::Connector/disconnect_on_destroy> except that it can be set
from within the constructor.

Default is on.

=head2 max_attempts

The maximum amount of block running attempts before the Connector gives up and dies.

Default is 10.

=head2 retry_debug

If enabled, any retries will output a debug warning with the error message and number
of retries.

=head2 retry_handler

An optional handler that will be checked on each retry.  It will be passed the Connector
object as its only input.  If the handler returns a true value, retries will continue.
A false value will cause the retry loop to immediately rethrow the exception.  You can
also throw your own, if you prefer.

This check is independent of checks for L</max_attempts>.

The last exception can be inspected as part of the check by looking at L</last_exception>.
This is recommended to make sure the failure is actually what you expect it to be.
For example:

    $conn->retry_handler(sub {
        my $c = shift;
        my $err = $c->last_exception;
        $err = $err->error if blessed $err && $err->isa('DBIx::Connector::RollbackError');

        # only retry on deadlocks or timeouts (only look in the first line
        # of the error to avoid e.g. accidental matches in a stack trace)
        $err =~ /^\V*(?:deadlock|timeout)/i;
    });

Default is an always-true coderef.

This attribute has the following handles:

=head3 clear_retry_handler

Sets it back to the always-true default.

=head2 execute_method

The current L<DBIx::Connector> execution method name being called, which would either be
C<run> or C<txn>.  Since C<svp> is not overridden, it would never be encountered.  If the
connector is not in the middle of DB block execution, this attribute is blank.

=head2 failed_attempt_count

The number of failed attempts so far.  This can be used in the L</retry_handler> or
checked afterwards.  It will be reset on each block run.

Not available for initialization.

=head2 exception_stack

The stack of exceptions received so far, as an arrayref.  This can be used in the
L</retry_handler> or checked afterwards.  It will be reset on each block run.

Not available for initialization.

This attribute has the following handles:

=head3 last_exception

The last exception on the stack.

=head1 CONSTRUCTORS

=head2 new

    my $conn = DBIx::Connector::Retry->new(
        connect_info => [ 'dbi:Driver:database=foobar', $user, $pass, \%args ],
        max_attempts => 5,
        # ...etc...
    );

    # Old-DBI syntax
    my $conn = DBIx::Connector::Retry->new(
        'dbi:Driver:database=foobar', $user, $pass, \%dbi_args,
        max_attempts => 5,
        # ...etc...
    );

As this is a L<Moo> class, it uses the standard Moo constructor.  The L</connect_info>
should be specified as its own key.  The L<DBI>/L<DBIx::Connector> syntax is available,
but only as a nicety for compatibility.

=head1 MODIFIED METHODS

=head2 run / txn

    my @result = $conn->run($mode => $coderef);
    my $result = $conn->run($mode => $coderef);
    $conn->run($mode => $coderef);

    my @result = $conn->txn($mode => $coderef);
    my $result = $conn->txn($mode => $coderef);
    $conn->txn($mode => $coderef);

Both L<run|DBIx::Connector/run> and L<txn|DBIx::Connector/txn> are modified to run inside
a retry loop.  If the original Connector action dies, the exception is caught, and if
L</retry_handler> and L</max_attempts> allows it, the action is retried.  The database
handle may be reset by the Connector action, according to its connection mode.

See L</CAVEATS> for important behaviors/limitations.

=head1 CAVEATS

=head2 $dbh settings

Like L<DBIx::Connector>, it's important that the L</connect_info> properties have sane
connection settings.

L<AutoCommit|DBI/AutoCommit> should be turned on.  Otherwise, the connection is
considered to be already in a transaction, and no retries will be attempted.  Instead,
use transactions via L<txn|DBIx::Connector/txn>.

L<RaiseError|DBI/RaiseError> should also be turned on, since exceptions are captured,
and both Retry and Connector use them to determine if any of the C<$dbh> calls failed.

=head2 Savepoints and nested transactions

L<The svp method|DBIx::Connector/svp> is NOT modified to work inside of a retry loop,
because retries are generally not possible for savepoints, and a disconnected connection
will rollback any uncommited statements in most RDBMS.  The same goes for any C<run>/C<txn>
calls attempted inside of a transaction.

Consider the following:

    # If this dies, sub will retry
    $conn->txn(ping => sub {
        shift->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');

        # If this dies, it will not retry
        $conn->svp(sub {
            my $c = shift;
            $c->do('INSERT foobar (name, updated, active) VALUES (?, ?)', undef, 'barbaz', 0, 'off');
        });
    });

If the savepoint actually tried to retry, the C<UPDATE> statement would get rolled back by
virtue of database disconnection.  However, the savepoint code would continue, possibly
even succeeding.  You would never know that the C<UPDATE> statement was rolled back.

However, without savepoint retry support, as it is currently designed, the statements
will work as expected.  If the savepoint code dies, and if C<$conn> is set up for
retries, the transaction code is restarted, after a rollback or reconnection.  Thus, the
C<UPDATE> and C<INSERT> statements are both ran properly if they now succeed.

Obviously, this will not work if transactions are manually started outside of the main
Connector interface:

    # Don't do this!  The whole transaction isn't compartmentalized properly!
    $conn->run(ping => sub {
        $_->begin_work;  # don't ever call this!
        $_->do('UPDATE foobar SET updated = 1 WHERE active = ?', undef, 'on');
    });

    # If this dies, the whole app will probably crash
    $conn->svp(sub {
        my $c = shift;
        $c->do('INSERT foobar (name, updated, active) VALUES (?, ?)', undef, 'barbaz', 0, 'off');
    });

    # Don't do this!
    $conn->run(ping => sub {
        $_->commit;  # no, let Connector handle this process!
    });

=head2 (Ab)using $dbh directly

For maximum retry protection, do not use the L<dbh|DBIx::Connector/dbh> or
L<connect|DBIx::Connector/connect> methods directly.  Directly accessing and using a DBI
database or statement handle does NOT grant retry protection, even if it was acquired
from those methods.  Furthermore, using those methods may trigger a connection failure,
which isn't protected by C<eval>.

Instead, only use the C<run>/C<txn> methods, and it will attempt the connection for you.
If the connection fails, retry protection kicks in, as it's part of the same retry loop.

=head2 Fixup mode

Because of the nature of L<fixup mode|DBIx::Connector/Connection Modes>, the block may be
executed twice as often.  Functionally, the code looks like this:

    # Very simplified example
    sub fixup_run {
        my ($self, $code) = @_;

        my (@ret, $run_err);
        do {
            eval {
                @ret = eval { $code->($dbh) };
                my $err = $@;

                if ($err) {
                    die $err if $self->connected;
                    # Not connected. Try again.
                    return $code->($dbh);
                }
            };
            $run_err = $@;

            if ($run_err) {
                # Push exception_stack, set/check attempts, check retry_handler
            }
        } while ($run_err);
        return @ret;
    }

If the first eval dies because of a connection failure, the code is ran twice before the
retry loop finds it.  This is only considered to be one attempt.  If it dies because of
some other fault, it's only ran once and continues the retry loop.

If this is behavior is undesirable, this can be worked around by using the L</retry_handler>
to change the L<mode|DBIx::Connector/mode> after the first attempt:

    $conn->retry_handler(sub {
        my $c = shift;
        $c->mode('ping') if $c->mode eq 'fixup';
        1;
    });

Mode is localized outside of the retry loop, so even C<< $conn->run(fixup => $code) >>
calls work, and the default mode will return to normal after the block run.

=head1 SEE ALSO

L<DBIx::Connector>, L<DBIx::Class>

=head1 AUTHOR

Grant Street Group <developers@grantstreet.com>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 - 2022 by Grant Street Group.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
