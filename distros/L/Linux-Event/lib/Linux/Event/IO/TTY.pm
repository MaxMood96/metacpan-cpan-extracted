package Linux::Event::IO::TTY;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use parent 'Linux::Event::_ByteStream';
use Carp qw(croak);

sub new ($class, %option) {
    if (defined(my $fh = $option{fh})) {
        croak 'new(): fh is not a TTY or PTY' if !-t $fh;
    } else {
        croak 'new(): read_fh is not a TTY or PTY'
            if defined($option{read_fh}) && !-t $option{read_fh};
        croak 'new(): write_fh is not a TTY or PTY'
            if defined($option{write_fh}) && !-t $option{write_fh};
    }
    return $class->SUPER::new(%option);
}

1;

__END__

=head1 NAME

Linux::Event::IO::TTY - asynchronous ordered-byte I/O for terminals and PTYs

=head1 SYNOPSIS

  package Console;
  use parent 'Linux::Event::IO::TTY';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($tty, $line) {
      $tty->write("You typed: $line\n");
  }

  package main;
  my $console = $loop->add(Console->new(
      read_fh  => \*STDIN,
      write_fh => \*STDOUT,
  ));

=head1 DESCRIPTION

C<Linux::Event::IO::TTY> is the public ordered-byte I/O class for terminals and
pseudo-terminals. It is appropriate for interactive standard input/output,
PTY-backed subprocess interfaces, and other terminal handles that should use
Linux::Event's native buffering and readiness machinery.

TTY owns asynchronous byte movement; it does not configure terminal modes,
echo, canonical input, baud rates, or other termios policy. Applications that
need those settings configure the terminal separately.

=head1 CONSTRUCTION

C<new> accepts a shared C<fh>, separate C<read_fh> and C<write_fh>, or either
direction alone. Every supplied handle must be a TTY or PTY according to Perl's
C<-t> test. Separate input and output handles are intentionally supported, so
C<STDIN> and C<STDOUT> can form one logical terminal object.

C<loop =E<gt> $loop> attaches immediately; detached objects may instead be
passed to C<< $loop->add($tty) >>. C<data> stores application state. Owned
handles are made nonblocking and close-on-exec.

Established C<idle_timeout>, C<read_timeout>, C<write_timeout>, and explicit
C<deadline> options use the common ordered-byte deadline model.

=head1 CALLBACKS AND FRAMING

A raw readable subclass defines C<on_data($tty, $bytes)>. A subclass that uses
L<Linux::Event::Framer> defines C<on_message($tty, $message)> or, with explicit
batching, C<on_messages($tty, $messages)>.

Delimiter framing is especially useful for line-oriented interactive input:

  use Linux::Event::Framer 'Delimiter', "\n";

Framing operates on the bytes Linux supplies after the terminal's own line
discipline. Linux::Event does not change canonical/raw terminal mode merely
because a framer is declared.

Optional lifecycle callbacks are C<on_eof>, C<on_drain>, C<on_error>, and
C<on_close>.

=head1 OUTPUT AND LIFECYCLE

C<write> submits raw bytes; C<send> applies the declared framer. Native output
queues preserve ordering and provide high/low-watermark backpressure.

C<pause_read> and C<resume_read> control application input. C<end> drains the
writable side, while C<close_read>, C<close_write>, and C<close> provide
immediate directional or whole-object termination.

C<detach> transfers still-open directional handles to the caller when no output
is queued. It is terminal and does not call C<on_close>.

=head1 CLASS POLICY

C<stream_options> configures the common ordered-byte engine. The main controls
are C<read_size>, C<read_budget_bytes>, raw-read or framed-message batching,
input/output limits, watermarks, and established deadlines. Policy is cached
per subclass so ordinary readiness does not perform option parsing or callback
lookup.

=head1 SEE ALSO

L<Linux::Event::IO::Pipe>, L<Linux::Event::IO::Sock::Stream>,
L<Linux::Event::Framer>, F<docs/ORDERED-BYTE-IO-DESIGN.md>.

=cut
