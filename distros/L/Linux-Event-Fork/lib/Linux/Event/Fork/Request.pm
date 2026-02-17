package Linux::Event::Fork::Request;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.005';

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

  my $h = $loop->fork(...);

  if ($h->isa('Linux::Event::Fork::Request')) {
    $h->cancel;   # prevent it from ever starting
  }

=head1 DESCRIPTION

When C<max_children> is enabled and the limit is reached, Fork enqueues the spawn
request and returns a Request object. Requests are started FIFO as capacity frees.

=head1 METHODS

=head2 cancel

Cancels a queued request (if it has not yet started). Returns true on first cancel.

=head2 started

True once the request has been started.

=head2 child

Returns the L<Linux::Event::Fork::Child> handle after the request starts.

=head2 tag / data

Metadata copied from the original spawn request.

=head1 AUTHOR

Joshua S. Day (HAX)

=head1 LICENSE

Same terms as Perl itself.

=cut
