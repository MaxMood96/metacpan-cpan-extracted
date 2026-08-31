use warnings;
use 5.042;

package IO::Async::Open3::Simple 0.01 {

    use IPC::Open3   qw( open3 );
    use Scalar::Util qw( reftype );
    use Symbol       qw( gensym );
    use IO::Async::Loop;
    use IO::Async::Stream;
    use IO::Async::Open3::Simple::Process;
    use Carp       qw( croak );
    use File::Temp ();

    # ABSTRACT: Interface to open3 under IO::Async


    sub new ( $class, @rest ) {
        my $default_handler = sub { };
        my $args            = ( reftype( $rest[0] ) || '' ) eq 'HASH' ? $rest[0] : {@rest};
        my %self;
        croak "stdin passed into IO::Async::Open3::Simple->new no longer supported" if $args->{stdin};
        croak "raw passed into IO::Async::Open3::Simple->new no longer supported"   if $args->{raw};
        $self{$_} = $args->{$_} || $default_handler
          for qw( on_stdout on_stderr on_start on_exit on_signal on_fail on_error on_success );
        $self{loop} = $args->{loop} if $args->{loop};
        bless \%self, $class;
    }


    sub run ( $self, @arguments ) {
        croak "run method requires at least one argument"
          unless @arguments >= 1;

        my $proc_user = ( ref $arguments[-1] eq 'CODE' ? pop @arguments : sub ($proc) { } );

        my $stdin;
        $stdin = pop @arguments if @arguments && ref $arguments[-1];

        my $program = shift @arguments;

        my ( $child_stdin, $child_stdout, $child_stderr );
        $child_stderr = gensym;

        # keep the temp file alive until open3 has dup'd it into the child
        my $stdin_file;
        if ( defined $stdin ) {
            $stdin_file = File::Temp->new;
            $stdin_file->autoflush(1);
            $stdin_file->print(
                ref($stdin) eq 'ARRAY'
                ? join( "\n", $stdin->@* )
                : $stdin->$*
            );
            $stdin_file->seek( 0, 0 );
            $child_stdin = '<&' . fileno($stdin_file);
        }

        my $loop = $self->{loop} ||= IO::Async::Loop->new;

        my $pid = eval { open3 $child_stdin, $child_stdout, $child_stderr, $program, @arguments };

        if ( my $error = $@ ) {
            $self->{on_error}->( $error, $program, @arguments );
            return;
        }

        my $proc = IO::Async::Open3::Simple::Process->new( $pid, $child_stdin );
        $proc_user->($proc);

        $self->{on_start}->( $proc, $program, @arguments );

        my $emit = sub ( $ref, $line ) {
            $line =~ s/(\015?\012|\015)$//;
            ref($ref) eq 'ARRAY' ? ( push $ref->@*, $line ) : $ref->( $proc, $line );
            return;
        };

        my $stdout_open = 1;
        my $stderr_open = 1;
        my $exited      = 0;
        my ( $exit_value, $signal );

        my ( $stdout_stream, $stderr_stream );

        my $finish = sub () {
            return if $stdout_open || $stderr_open || !$exited;

            $proc->close;

            $self->{on_exit}->( $proc, $exit_value, $signal );
            $self->{on_signal}->( $proc, $signal )   if $signal > 0;
            $self->{on_fail}->( $proc, $exit_value ) if $exit_value > 0;
            $self->{on_success}->($proc)             if $signal == 0 && $exit_value == 0;

            undef $stdout_stream;
            undef $stderr_stream;
            undef $proc;
            return;
        };

        my $make_stream = sub ( $handle, $which, $open_ref ) {
            my $stream = IO::Async::Stream->new(
                read_handle => $handle,
                on_read     => sub ( $, $buffref, $eof ) {
                    while ( $buffref->$* =~ s/^(.*?\012)// ) {
                        $emit->( $self->{$which}, $1 );
                    }
                    if ( $eof && length $buffref->$* ) {
                        my $line = $buffref->$*;
                        $buffref->$* = '';
                        $emit->( $self->{$which}, $line );
                    }
                    return 0;
                },
                on_read_eof => sub ($) {
                    $open_ref->$* = 0;
                    $finish->();
                    return;
                },
            );
            $loop->add($stream);
            return $stream;
        };

        $stdout_stream = $make_stream->( $child_stdout, 'on_stdout', \$stdout_open );
        $stderr_stream = $make_stream->( $child_stderr, 'on_stderr', \$stderr_open );

        $loop->watch_process(
            $pid => sub ( $, $status ) {
                ( $exit_value, $signal ) = ( $status >> 8, $status & 127 );
                $exited = 1;
                $finish->();
                return;
            }
        );

        $self;
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::Async::Open3::Simple - Interface to open3 under IO::Async

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use v5.42;
 use IO::Async::Loop;
 use IO::Async::Open3::Simple;

 my $loop = IO::Async::Loop->new;
 my $done = $loop->new_future;

 my $ipc = IO::Async::Open3::Simple->new(
   on_start => sub ($proc, $program, @args) {
     # $proc    isa IO::Async::Open3::Simple::Process
     # $program is a string
     # @args    is the list of arguments
     say 'child PID: ', $proc->pid;
   },
   on_stdout => sub ($proc, $line) {
     say 'out: ', $line;
   },
   on_stderr => sub ($proc, $line) {
     say 'err: ', $line;
   },
   on_exit => sub ($proc, $exit_value, $signal) {
     say 'exit value: ', $exit_value;
     say 'signal:     ', $signal;
     $done->done;
   },
   on_error => sub ($error, $program, @args) {
     # $error is the exception thrown by IPC::Open3::open3
     warn "error: $error";
     $done->done;
   },
 );

 $ipc->run('echo', 'hello there');
 $done->get;

=head1 DESCRIPTION

This module provides an interface to open3 while running under L<IO::Async>
that delivers data from stdout and stderr as lines are written by the
subprocess.  The interface is reminiscent of L<IPC::Open3::Simple>,
although this module does provide a somewhat different API, so it
cannot be used as a drop in replacement for that module.

It is intended as a drop in replacement for L<AnyEvent::Open3::Simple>,
for code that would rather use L<IO::Async> as its event loop.  Aside
from the C<AnyEvent> specific parts (the C<implementation> attribute
and the C<ANYEVENT_OPEN3_SIMPLE> environment variable, neither of which
apply here), the API is the same.

L<IO::Async> comes with a robust interface to do the same thing as this
module: L<IO::Async::Process>, which you more than likely want to use
instead.  This module is primarily intended for applications that are
already using L<AnyEvent::Open3::Simple> and only want to change the
underlying event loop.

=head1 CONSTRUCTOR

Constructor takes a hash or hashref of event callbacks and attributes.
Event callbacks have an C<on_> prefix, attributes do not.

=head2 ATTRIBUTES

=over 4

=item * loop

The L<IO::Async::Loop> to use.  If not provided the shared loop returned
by C<< IO::Async::Loop->new >> is used, which is almost always what you
want.

=item * implementation

Accepted and ignored for compatibility with L<AnyEvent::Open3::Simple>.
Under L<IO::Async> there is only one implementation: an L<IO::Async::Stream>
for each of stdout and stderr, and C<< $loop->watch_process >> to detect
process termination.

=back

=head2 EVENTS

These events will be triggered by the subprocess when the run method is
called. Each event callback (except C<on_error>) gets passed in an
instance of L<IO::Async::Open3::Simple::Process> as its first argument
which can be used to get the PID of the subprocess, or to write to it.
C<on_error> does not get a process object because it indicates an error in
the creation of the process.

Not all of these events will fire depending on the execution of the
child process.  In the very least exactly one of C<on_start> or C<on_error>
will be called.

=over 4

=item * C<on_start> ($proc, $program, @arguments)

Called after the process is created, but before the run method returns
(that is, it does not wait to re-enter the event loop first).

This event also gets the program name and arguments passed into the
L<run|IO::Async::Open3::Simple#run> method.

=item * C<on_error> ($error, $program, @arguments)

Called when there is an execution error, for example, if you ask
to run a program that does not exist.  No process is passed in
because the process failed to create.  The error passed in is
the error thrown by L<IPC::Open3> (typically a string which begins
with "open3: ...").

In some environments open3 is unable to detect exec errors in the
child, so you may not be able to rely on this event.  It does
seem to work consistently on Perl 5.14 or better though.

Different environments have different ways of handling it when
you ask to run a program that doesn't exist.  On Linux and Cygwin,
this will raise an C<on_error> event, on C<MSWin32> it will
not trigger a C<on_error> and instead cause a normal exit
with a exit value of 1.

This event also gets the program name and arguments passed into the
L<run|IO::Async::Open3::Simple#run> method.

=item * C<on_stdout> ($proc, $line)

Called on every line printed to stdout by the child process.

=item * C<on_stderr> ($proc, $line)

Called on every line printed to stderr by the child process.

=item * C<on_exit> ($proc, $exit_value, $signal)

Called when the processes completes, either because it called exit,
or if it was killed by a signal.

=item * C<on_success> ($proc)

Called when the process returns zero exit value and is not terminated by a signal.

=item * C<on_signal> ($proc, $signal)

Called when the processes is terminated by a signal.

=item * C<on_fail> ($proc, $exit_value)

Called when the process returns a non-zero exit value.

=back

=head1 METHODS

=head2 run

 $ipc->run($program, @arguments);
 $ipc->run($program, @arguments, \$stdin);
 $ipc->run($program, @arguments, \@stdin);
 $ipc->run($program, @arguments, sub {...});
 $ipc->run($program, @arguments, \$stdin, sub {...});
 $ipc->run($program, @arguments, \@stdin, sub {...});

Start the given program with the given arguments.  Returns
immediately (it returns the L<IO::Async::Open3::Simple> instance).
Any events that have been specified in the constructor (except for
C<on_start>) will not be called until the process re-enters the
event loop.

You may optionally provide the full content of standard input
as a string reference or list reference as the last argument
(or second to last if you are providing a callback below).
If provided as a list reference, it will be joined by new lines
in whatever format is native to your Perl.  Currently on
(non cygwin) Windows (Strawberry, ActiveState) this is the only
way to provide standard input to the subprocess.

Do not mix the use of passing standard input to L<run|IO::Async::Open3::Simple#run>
and L<IO::Async::Open3::Simple::Process#print> or L<IO::Async::Open3::Simple::Process#say>,
otherwise bad things may happen.

You may provide a callback as the last argument which is called before
C<on_start>, and takes the process object as its only argument.  For
example:

 foreach my $i (1..10)
 {
   $ipc->run($prog, @args, \$stdin, sub ($proc) {
     $proc->user({ iteration => $i });
   });
 }

This is useful for making data accessible to C<$ipc> object's callbacks that may
be out of scope otherwise.

=head1 CAVEATS

There are some traps for the unwary relating to buffers and deadlocks,
L<IPC::Open3> is recommended reading.

Unlike L<AnyEvent::Open3::Simple>, this module waits for the child's
stdout and stderr pipes to reach end of file (in addition to the child
process being reaped) before firing C<on_exit>.  This guarantees that
every line of output is delivered before C<on_exit>, but a grandchild
process which inherits and holds open the pipes can delay the event.

If you register a call back for C<on_exit>, but not C<on_error> then
use a L<Future> (or condition variable, or C<< $loop->run >> / C<< $loop->stop >>)
to wait for the process to complete as in this:

 my $done = $loop->new_future;
 my $ipc = IO::Async::Open3::Simple->new(
   on_exit => sub (@) { $done->done },
 );
 $ipc->run('command_not_found');
 $done->get;

You might be waiting forever if there is an error starting the
process (if for example you give it a bad command).  To handle
this situation you might fail the Future in the event of error:

 my $done = $loop->new_future;
 my $ipc = IO::Async::Open3::Simple->new(
   on_exit => sub (@) { $done->done },
   on_error => sub ($error, @) {
     $done->fail($error);
   },
 );
 $ipc->run('command_not_found');
 $done->get;

This will cause the C<get> to die, printing a useful diagnostic
if the exception isn't caught somewhere else.

Writing to a subprocesses stdin with L<IO::Async::Open3::Simple::Process#print>
or L<IO::Async::Open3::Simple::Process#say> is unsupported on Microsoft
Windows (it does work under Cygwin though).

=head1 SEE ALSO

=over 4

=item L<IO::Async::Open3::Simple::Process>

Represents a process being run by this module, typically passed
into the callbacks.

=item L<AnyEvent::Open3::Simple>

The module this one is based on, for use with L<AnyEvent> instead
of L<IO::Async>.

=item L<IO::Async::Process>

Alternative to this module included with L<IO::Async>.

=back

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
