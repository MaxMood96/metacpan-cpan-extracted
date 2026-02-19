package Linux::Event::Fork::Exit;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.006';

use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

# WCOREDUMP is not available/exported on all Perls/platforms.
# Detect it at compile time and gracefully return 0 when unavailable.
my $HAS_WCOREDUMP = defined &POSIX::WCOREDUMP ? 1 : 0;

sub new ($class, $status) { return bless { status => $status }, $class }
sub status   ($self) { return $self->{status} }

sub exited   ($self) { return WIFEXITED($self->{status}) ? 1 : 0 }
sub code     ($self) { return WEXITSTATUS($self->{status}) }

sub signaled ($self) { return WIFSIGNALED($self->{status}) ? 1 : 0 }
sub signal   ($self) { return WTERMSIG($self->{status}) }

sub coredump ($self) {
  return 0 if !$HAS_WCOREDUMP;
  return POSIX::WCOREDUMP($self->{status}) ? 1 : 0;
}

1;

__END__

=head1 NAME

Linux::Event::Fork::Exit - Value object describing how a child process ended

=head1 SYNOPSIS

  $loop->fork(
    cmd => [ ... ],
    on_exit => sub ($child, $exit) {
      if ($exit->exited) {
        say "exit code = " . $exit->code;
      } else {
        say "signal    = " . $exit->signal;
      }
    },
  );

=head1 DESCRIPTION

A C<Linux::Event::Fork::Exit> object describes the termination state of a child
process. It is passed to the C<on_exit> callback in the parent process.

It provides a stable, explicit interface over the raw C<waitpid> status.

=head1 EXECUTION MODEL

Exit objects are created and observed in the B<parent process>.

The C<on_exit> callback always runs in the parent, inside the Linux::Event
event loop.

=head1 METHODS

=head2 pid

  my $pid = $exit->pid;

Process ID of the child that exited.

=head2 status

  my $status = $exit->status;

The raw wait status integer as returned by C<waitpid>.

=head2 exited

  if ($exit->exited) { ... }

True if the child exited normally (via C<exit()> or returning from C<main>).

=head2 code

  my $code = $exit->code;

Exit code (0..255) if C<exited> is true.

Undefined if the child died due to a signal.

=head2 signaled

  if ($exit->signaled) { ... }

True if the child terminated due to a signal.

=head2 signal

  my $sig = $exit->signal;

Signal number if C<signaled> is true.

Undefined if the child exited normally.

=head2 coredump

  if ($exit->coredump) { ... }

True if the child produced a core dump (platform-dependent).

=head1 INTERPRETATION GUIDE

Exactly one of these will be true:

=over 4

=item * C<< $exit->exited >>

Normal termination; use C<< $exit->code >>.

=item * C<< $exit->signaled >>

Signal termination; use C<< $exit->signal >> (and optionally C<< $exit->coredump >>).

=back

=head1 AUTHOR

Joshua S. Day (HAX)

=head1 LICENSE

Same terms as Perl itself.

=cut
