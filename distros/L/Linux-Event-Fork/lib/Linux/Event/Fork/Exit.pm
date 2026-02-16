package Linux::Event::Fork::Exit;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.003';

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

Linux::Event::Fork::Exit - Exit-status helper object (abstracts POSIX wait macros)

=head1 SYNOPSIS

  on_exit => sub ($child, $exit) {
    if ($exit->exited) {
      say "exit code: " . $exit->code;
    } elsif ($exit->signaled) {
      say "signal: " . $exit->signal;
    }
  }

=head1 DESCRIPTION

Wraps the raw wait status integer and exposes methods so user code does not need to
use POSIX macros like C<WIFEXITED>, C<WEXITSTATUS>, C<WIFSIGNALED>, or C<WTERMSIG>.

=head1 METHODS

=head2 status

Raw wait status integer.

=head2 exited / code

Normal exit and exit code (0..255).

=head2 signaled / signal

Terminated by signal and signal number.

=head2 coredump

True if a core dump occurred (when available on this Perl/platform). If the
platform does not provide C<WCOREDUMP>, this method returns false.

=head1 AUTHOR

Joshua S. Day (HAX)

=head1 LICENSE

Same terms as Perl itself.

=cut
