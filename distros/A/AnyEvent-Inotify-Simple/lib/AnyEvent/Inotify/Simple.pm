package AnyEvent::Inotify::Simple;
$AnyEvent::Inotify::Simple::VERSION = '0.04';
use Moose;

# ABSTRACT: monitor a directory tree in a non-blocking way

use MooseX::FileAttribute;
use MooseX::Types::Moose qw(HashRef CodeRef ArrayRef Int);
use MooseX::Types -declare => ['Receiver'];

use AnyEvent::Inotify::EventReceiver;
use AnyEvent::Inotify::EventReceiver::Callback;

role_type Receiver, { role => 'AnyEvent::Inotify::EventReceiver' };

coerce Receiver, from CodeRef, via {
    AnyEvent::Inotify::EventReceiver::Callback->new(
        callback => $_,
    ),
};

use AnyEvent;
use Linux::Inotify2;
use File::Next;

use namespace::clean -except => ['meta'];

has_directory 'directory' => ( must_exist => 1, required => 1);

has 'filter' => (
    traits   => ['Code'],
    is       => 'ro',
    isa      => CodeRef,
    handles  => { is_filtered => 'execute' },
    default  => sub {
        sub { return 0 },
    },
);

has 'event_receiver' => (
    is       => 'ro',
    isa      => Receiver,
    handles  => 'AnyEvent::Inotify::EventReceiver',
    required => 1,
    coerce   => 1,
);

has 'inotify' => (
    init_arg   => undef,
    is         => 'ro',
    isa        => 'Linux::Inotify2',
    handles    => [qw/poll fileno watch/],
    lazy_build => 1,
);

sub _build_inotify {
    my $self = shift;

    my $inotify = Linux::Inotify2->new or confess "Inotify initialization failed: $!";
    # Ignore overflows, rather than broadcasting to every watcher
    $inotify->on_overflow(sub {});
    return $inotify;
}

has 'wanted_events' => (
    is         => 'ro',
    isa        => ArrayRef,
    default => sub {
      [ qw(access modify attribute_change close_write close_nowrite open create delete move) ]
    },
);

has '_wanted_events_mask' => (
    is         => 'ro',
    isa        => Int,
    lazy_build => 1,
);

my %event_to_mask = (
    access           => IN_ACCESS,
    modify           => IN_MODIFY,
    attribute_change => IN_ATTRIB,
    close_write      => IN_CLOSE_WRITE,
    close_nowrite    => IN_CLOSE_NOWRITE,
    open             => IN_OPEN,
    create           => IN_CREATE,
    delete           => IN_DELETE,
    move             => IN_MOVED_FROM | IN_MOVED_TO,
);

sub _build__wanted_events_mask {
    my $mask = 0;
    for (@{$_[0]->wanted_events}) {
        my $event_mask = $event_to_mask{$_}
            || die "Unknown wanted event: $_";
        $mask |= $event_mask;
    }
    return $mask;
}

has 'io_watcher' => (
    init_arg => undef,
    is       => 'ro',
    builder  => '_build_io_watcher',
    required => 1,
);

sub _build_io_watcher {
    my $self = shift;

    return AnyEvent->io(
        fh   => $self->fileno,
        poll => 'r',
        cb   => sub { $self->poll },
    );
}

has 'cookie_jar' => (
    init_arg => undef,
    is       => 'ro',
    isa      => HashRef,
    required => 1,
    default  => sub { +{} },
);

sub _watch_directory {
    my ($self, $dir) = @_;

    my $next = File::Next::dirs({
        follow_symlinks => 0,
    }, $dir);

    while ( my $entry = $next->() ) {
        last unless defined $entry;
        next if $self->is_filtered($entry);

        if( -d $entry ){
            $entry = Path::Class::dir($entry);
        }
        else {
            $entry = Path::Class::file($entry);
        }

        $self->watch(
            $entry->stringify,
            $self->_wanted_events_mask,
            sub { $self->handle_event($entry, $_[0]) },
        );
    }
}

sub BUILD {
    my $self = shift;

    $self->_watch_directory($self->directory->resolve->absolute);
}

my %events = (
    IN_ACCESS        => 'handle_access',
    IN_MODIFY        => 'handle_modify',
    IN_ATTRIB        => 'handle_attribute_change',
    IN_CLOSE_WRITE   => 'handle_close_write',
    IN_CLOSE_NOWRITE => 'handle_close_nowrite',
    IN_OPEN          => 'handle_open',
    IN_CREATE        => 'handle_create',
    IN_DELETE        => 'handle_delete',
);

sub handle_event {
    my ($self, $file, $event) = @_;

    my $wrapper = $event->IN_ISDIR ? 'subdir' : 'file';
    my $event_file = $file->$wrapper($event->name);

    if( $event->IN_DELETE_SELF || $event->IN_MOVE_SELF ){
        #warn "canceling $file";
        #$event->w->cancel;
        return;
    }

    if($self->is_filtered($event_file)){
        # we get this when a directory watcher notices something
        # about a file that should be ignored
        return;
    }

    my $relative = $event_file->relative($self->directory);
    my $handled = 0;

    for my $type (keys %events){
        my $method = $events{$type};
        if( $event->$type ){
            $self->$method($relative);
            $handled = 1;
        }
    }

    if( $event->IN_MOVED_FROM ){
        $self->handle_move_from($relative, $event->cookie);
        $handled = 1;
    }

    if( $event->IN_MOVED_TO ){
        $self->handle_move_to($relative, $event->cookie);
        $handled = 1;
    }

    if (!$handled){
        require Data::Dumper;
        local $Data::Dumper::Maxdepth = 2;
        Carp::cluck "BUGBUG: Unhandled event: ".
              Data::Dumper->Dump($event);
    }

}

sub rel2abs {
    my ($self, $file) = @_;

    return $file if $file->is_absolute;
    return $file->absolute($self->directory)->resolve->absolute;
}

sub handle_move_from {
    my ($self, $file, $cookie) = @_;

    $self->cookie_jar->{from}{$cookie} = $file;
}

sub handle_move_to {
    my ($self, $to, $cookie) = @_;

    my $from = delete $self->cookie_jar->{from}{$cookie};
    confess "Invalid move cookie '$cookie' (moved to '$to')"
        unless $from;

    my $abs = eval { $self->rel2abs($to) };
    $self->_watch_directory($abs) if $abs && -d $abs;

    $self->handle_move($from, $to);
}

# inject our magic
before 'handle_create' => sub {
    my ($self, $dir) = @_;
    my $abs = eval { $self->rel2abs($dir) };
    return unless $abs && -d $abs;
    $self->_watch_directory($abs);
};

sub DEMOLISH {
    my $self = shift;
    return unless $self->inotify;
    for my $w (values %{$self->inotify->{w}}){
        next unless $w;
        $w->cancel;
    }
}

1;

__END__

=head1 NAME

AnyEvent::Inotify::Simple - monitor a directory tree in a non-blocking way

=head1 SYNOPSIS

   use AnyEvent::Inotify::Simple;
   use EV; # or POE, or Event, or ...

   my $inotify = AnyEvent::Inotify::Simple->new(
       directory      => '/tmp/uploads/',
       wanted_events  => [ qw(create move) ],
       event_receiver => sub {
           my ($event, $file, $moved_to) = @_;
           given($event) {
               when('create'){
                  say "Someone just uploaded $file!"
               }
           };
       },
   );

   EV::loop;

=head1 DESCRIPTION

This module is a wrapper around L<Linux::Inotify2> that integrates it
with an L<AnyEvent> event loop and makes monitoring a directory
simple.  Provide it with a C<directory>, C<event_receiver>
(L<AnyEvent::Inotify::Simple::EventReceiver>), and an optional coderef
C<filter> and/or optional array ref C<wanted_events>, and it will
monitor an entire directory tree.  If something
is added, it will start watching it.  If something goes away, it will
stop watching it.  It also converts C<IN_MOVE_FROM> and C<IN_MOVE_TO>
into one virtual event.

Someday I will write more, but that's really all that happens!

=head1 METHODS

None!  Create the object, and it starts working immediately.  Destroy
the object, and the inotify state and watchers are automatically
cleaned up.

=head1 REPOSITORY

Forks welcome!

L<http://github.com/jrockway/anyevent-inotify-simple>

=head1 AUTHOR

Jonathan Rockway C<< <jrockway@cpan.org> >>

Current maintainer is Rob N ★ C<< <robn@robn.io> >>

=head1 COPYRIGHT

Copyright 2009 (c) Jonathan Rockway.  This module is Free Software.
You may redistribute it under the same terms as Perl itself.
