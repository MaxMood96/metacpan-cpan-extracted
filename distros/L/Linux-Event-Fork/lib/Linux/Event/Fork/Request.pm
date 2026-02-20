package Linux::Event::Fork::Request;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.007';

use Carp qw(croak);

sub _new ($class, %args) {
  my $fork = delete $args{fork} or croak "fork missing";
  my $spec = delete $args{spec} or croak "spec missing";
  croak "unknown args: " . join(", ", sort keys %args) if %args;

  # Copy the spec now so later mutation by the caller cannot affect queued work.
  my %copy = %$spec;

  my $self = bless {
    fork => $fork,
    spec => \%copy,
    canceled => 0,
    started => 0,
    child => undef,
    tag  => $copy{tag},
    data => $copy{data},
  }, $class;

  return $self;
}

sub tag ($self)  { return $self->{tag} }
sub data ($self) { return $self->{data} }

sub started ($self) { return $self->{started} ? 1 : 0 }
sub child   ($self) { return $self->{child} }

sub cancel ($self) {
  return 0 if $self->{canceled};
  $self->{canceled} = 1;
  return 1;
}

sub _canceled ($self) { return $self->{canceled} ? 1 : 0 }

sub _start ($self) {
  return if $self->{canceled};
  return if $self->{started};

  $self->{started} = 1;

  my $child = $self->{fork}->_spawn_now($self->{spec});
  $self->{child} = $child;

  return $child;
}

1;

__END__

=head1 NAME

Linux::Event::Fork::Request - A queued spawn request when max_children is reached

=head1 SYNOPSIS

  my $forker = Linux::Event::Fork->new($loop, max_children => 2);

  my $h = $forker->spawn(cmd => [ ... ]);

  if ($h->isa('Linux::Event::Fork::Request')) {
    $h->cancel;   # prevent it from ever starting
  }

=head1 DESCRIPTION

When bounded parallelism is enabled (C<max_children>) and the limit has been
reached, L<Linux::Event::Fork> enqueues the spawn request and returns a Request
object.

Requests are started FIFO as capacity frees.

A Request is a handle for I<queued work>. Once it starts, it produces a
L<Linux::Event::Fork::Child>.

=head1 EXECUTION MODEL

All methods on this object are called from the B<parent process>.

Starting of queued requests happens in the parent, driven by the event loop
when capacity becomes available.

=head1 IMPORTANT BEHAVIOR

=head2 Spec is copied at enqueue time

The original spawn spec is copied when the Request is created. Later mutation by
the caller cannot affect queued work.

=head1 METHODS

=head2 cancel

  my $ok = $req->cancel;

Cancels a queued request (only if it has not yet started).

Returns true on the first successful cancel, false if it was already canceled.

If the request has already started, cancel has no effect on the child.

=head2 started

  if ($req->started) { ... }

True once the request has started and a child has been spawned.

=head2 child

  my $child = $req->child;

Returns the L<Linux::Event::Fork::Child> handle once the request starts.

Returns undef while still queued (or if canceled before start).

=head2 tag

  my $tag = $req->tag;

Returns the tag copied from the original spawn request.

=head2 data

  my $data = $req->data;

Returns the data payload copied from the original spawn request.

=head1 RELATIONSHIP TO cancel_queued

L<Linux::Event::Fork> provides C<cancel_queued(...)> on the forker object to cancel
queued requests in bulk (typically by predicate, tag, or data).

This object-level C<cancel()> cancels exactly one specific request handle.

=head1 AUTHOR

Joshua S. Day (HAX)

=head1 LICENSE

Same terms as Perl itself.

=cut
