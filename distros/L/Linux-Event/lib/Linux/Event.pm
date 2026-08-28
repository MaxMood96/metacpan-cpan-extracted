package Linux::Event;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.103';

1;

__END__

=head1 NAME

Linux::Event - Linux-native reactor, streams, datagrams, and processes

=head1 SYNOPSIS

  use Linux::Event::Loop;
  use Linux::Event::Stream;

  my $loop = Linux::Event::Loop->new;
  $loop->add(MyStream->connect(
      host => '127.0.0.1', # required
      port => 9999,        # required
  ));
  $loop->run;

=head1 DESCRIPTION

Linux::Event is a Linux-only asynchronous I/O distribution. The
XS-first C<Linux::Event::Loop> reactor owns native descriptor registrations.
Public Stream, Listener, Datagram, Timer, Signal, Wakeup, and Process objects
own their logical resources and attach directly to one Loop; they do not
inherit from a generic Watcher or IO class.

The APIs deliberately remain layered.  Applications that need raw descriptor
readiness can use the reactor directly.  Applications that want automatic
socket reads, buffered writes, and native message framing can use a Stream
subclass on top.

Every attachable public object accepts C<loop =E<gt> $loop>. It can instead be
constructed detached and passed to C<< $loop->add($object) >>. C<add> sets the
Loop, starts the object's activity, and returns the same object.

=head1 MAIN MODULES

=over 4

=item * L<Linux::Event::Loop>

XS-first epoll reactor and native watcher registry.

=item * L<Linux::Event::Stream>

Subclass-defined buffered byte streams with connection, framing, backpressure,
half-close, established deadlines, protocol-transition, and transport lifecycle.

=item * L<Linux::Event::Listener>

TCP and Unix listeners that automatically construct a chosen Stream subclass.

=item * L<Linux::Event::Datagram>

Connected and unconnected UDP and Unix datagram sockets that preserve packet
boundaries and peer addresses.

=item * L<Linux::Event::Timer>

Subclass-defined one-shot and fixed-rate recurring monotonic timers.

=item * L<Linux::Event::Signal>

Subclass-defined synchronous signalfd subscriptions with native fan-out.

=item * L<Linux::Event::Wakeup>

Subclass-defined eventfd notifications that foreign threads or forked children
may signal without transferring Perl callbacks or values.

=item * L<Linux::Event::Process>

pidfd lifecycle notification, native process spawning, decoded exit status,
signals, and asynchronous standard I/O.

=item * L<Linux::Event::TLS>

Declarative OpenSSL TLS policy for Stream subclasses.

=item * L<Linux::Event::Framer>

Guide to selecting a framing strategy for message-oriented protocols.

=item * L<Linux::Event::Error>

Structured errors shared by socket, process, connection, and transport paths.

=item * L<Linux::Event::Address>

Lazy IPv4, IPv6, and Unix socket-address values.

=back

=head1 PUBLIC MODEL

Applications subclass C<Linux::Event::Stream> and
C<Linux::Event::Datagram> to define network behavior,
C<Linux::Event::Timer> to define scheduled behavior,
C<Linux::Event::Signal> to define signal behavior,
C<Linux::Event::Wakeup> to define notification handling, and
C<Linux::Event::Process> to define child lifecycle handling. They do not
subclass Loop registrations. Outbound Stream acquisition is
C<< MyStream->connect(host =E<gt> '127.0.0.1', port =E<gt> 9999) >>. Inbound
Stream acquisition is C<< Linux::Event::Listener->new(stream_class =E<gt>
'MyStream', host =E<gt> '0.0.0.0', port =E<gt> 9999) >>. A Stream subclass
opts into TLS with C<use Linux::Event::TLS>; C<connect> and Listener acceptance
select the client or server handshake role.

C<< $loop->watch(fd =E<gt> $fd, read =E<gt> $callback) >> remains available
for low-level descriptor readiness.
It immediately returns an opaque native registration handle with methods such
as C<cancel>, C<enable_read>, and C<disable_write>. That handle is not a named
public class or a subclassing contract.

=head1 PLATFORM

Linux only. Building the complete distribution requires Linux headers with
pidfd syscall definitions, a Linux 5.4 or newer runtime for pidfd status,
a libc providing C<posix_spawn_file_actions_addchdir_np>, and OpenSSL 1.1.1 or
newer development files. Perl ithreads are not required.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
