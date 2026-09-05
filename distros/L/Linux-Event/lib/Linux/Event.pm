package Linux::Event;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

1;

__END__

=head1 NAME

Linux::Event - Linux-native reactor, I/O, and kernel event facilities

=head1 SYNOPSIS

  use Linux::Event::Loop;
  use Linux::Event::IO::Sock::Stream;

  package EchoClient;
  use parent 'Linux::Event::IO::Sock::Stream';

  sub on_data ($self, $bytes) {
      print $bytes;
  }

  package main;
  my $loop = Linux::Event::Loop->new;
  $loop->add(EchoClient->connect(
      host => '127.0.0.1',
      port => 9999,
  ));
  $loop->run;

=head1 DESCRIPTION

Linux::Event is a Linux-only asynchronous I/O distribution built around an
XS-first epoll reactor. Its public resource model is divided into two semantic
namespaces:

=over 4

=item * L<Linux::Event::IO>

Application data I/O. Applications select a concrete leaf for the Linux
facility they are using, such as a pipe, terminal, stream socket, listener, or
datagram socket.

=item * L<Linux::Event::Kernel>

Kernel notification and state facilities such as timers, signals, eventfd
notifications, and process lifecycle handling.

=back

C<Linux::Event::IO> and C<Linux::Event::Kernel> are namespace categories, not
generic objects and not public subclassing bases. Public classes are concrete
semantic leaves. Shared buffering, framing, socket, descriptor, and lifecycle
machinery remains private implementation detail.

Every attachable resource accepts C<loop =E<gt> $loop> where supported. A
resource may instead be constructed unattached and passed to
C<< $loop->add($object) >>. Low-level descriptor readiness remains available
directly from L<Linux::Event::Loop>.

=head1 I/O MODULES

=over 4

=item * L<Linux::Event::IO::Pipe>

Ordered byte I/O for anonymous pipes, FIFOs, and child-process pipe handles.
It may be read-only, write-only, or use separate read and write pipe handles.

=item * L<Linux::Event::IO::TTY>

Ordered byte I/O for terminals and pseudo-terminals. The class validates that
its configured handles are terminal devices.

=item * L<Linux::Event::IO::Sock::Stream>

Connected C<SOCK_STREAM> sockets. IPv4, IPv6, and Unix-domain sockets use the
same leaf; address family is configuration rather than a different class.
This leaf owns outbound C<connect>, socket options, addresses, kernel
half-close behavior, buffering, framing, backpressure, and optional TLS.

=item * L<Linux::Event::IO::Sock::Listener>

Listening C<SOCK_STREAM> sockets for TCP and Unix-domain endpoints. Accepted
connections are constructed as a chosen C<Linux::Event::IO::Sock::Stream>
subclass.

=item * L<Linux::Event::IO::Sock::Dgram>

C<SOCK_DGRAM> sockets preserving packet boundaries and peer addresses for UDP
and Unix-domain datagrams.

=back

=head1 KERNEL MODULES

=over 4

=item * L<Linux::Event::Kernel::Timer>

Subclass-defined one-shot and recurring monotonic timer behavior.

=item * L<Linux::Event::Kernel::Signal>

Subclass-defined signalfd subscriptions with native fan-out.

=item * L<Linux::Event::Kernel::Event>

Eventfd-backed notifications. Foreign threads or forked children can signal a
registered object without transferring Perl callbacks or Perl values.

=item * L<Linux::Event::Kernel::Process>

Pidfd lifecycle notification, native process spawning, decoded exit status,
signals, and asynchronous standard I/O.

=back

=head1 SUPPORTING MODULES

=over 4

=item * L<Linux::Event::Loop>

XS-first epoll reactor, native descriptor registry, query-driven introspection,
and optional profiling.

=item * L<Linux::Event::Framer>

Declarative native framing for ordered-byte I/O subclasses. Framing applies to
pipe, TTY, and C<SOCK_STREAM> leaves because it is a byte-stream behavior, not
a socket-specific feature.

=item * L<Linux::Event::TLS>

Declarative OpenSSL TLS policy for C<Linux::Event::IO::Sock::Stream>
subclasses.

=item * L<Linux::Event::Error>

Structured errors shared by I/O, process, connection, and transport paths.

=item * L<Linux::Event::Address>

Lazy IPv4, IPv6, and Unix socket-address values.

=back

=head1 PUBLIC MODEL

Applications subclass the concrete leaf that describes the resource being
used. For example:

  package Protocol;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($self, $message) {
      $self->send($message);
  }

A listener then names that completed stream-socket class:

  my $listener = Linux::Event::IO::Sock::Listener->new(
      loop         => $loop,
      stream_class => 'Protocol',
      host         => '0.0.0.0',
      port         => 9999,
  );

The category names C<IO> and C<Kernel> do not imply a Perl inheritance tree.
Likewise, implementation sharing does not make private machinery part of the
public API. The public name identifies the final semantic resource; internal
layers may be reorganized without changing that leaf.

C<< $loop->watch(fd =E<gt> $fd, read =E<gt> $callback) >> remains available
for direct descriptor readiness. It returns an opaque native registration
handle with operations such as C<cancel>, C<enable_read>, and
C<disable_write>. That registration is not a named public subclassing class.

=head1 PLATFORM

Linux only. Building the complete distribution requires Linux headers with
pidfd syscall definitions, a Linux 5.4 or newer runtime for pidfd status,
a libc providing C<posix_spawn_file_actions_addchdir_np>, and OpenSSL 1.1.1 or
newer development files. Perl ithreads are not required. Configuration on an
unsupported operating system exits with an C<OS unsupported> result so
automated smoke systems can classify the distribution as not applicable.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
