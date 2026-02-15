package Mojo::File::ChangeNotify 0.01;
use 5.020;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use Mojo::File::ChangeNotify::WatcherProcess 'watch';
use Mojo::IOLoop::Subprocess;

=head1 NAME

Mojo::File::ChangeNotify - turn file changes into Mojo events

=head1 SYNOPSIS

  my $watcher =
    Mojo::File::ChangeNotify->instantiate_watcher
        ( directories => [ '/my/path', '/my/other' ],
          filter      => qr/\.(?:pm|conf|yml)$/,
          on_change   => sub( $watcher, @event_lists ) {
              ...
          },
        );

  # alternatively
  $watcher->on( 'change' => sub( $watcher, @event_lists ) {
      for my $l (@event_lists) {
          for my $e ($l->@*) {
              print "[$e->{type}] $e->{path}\n";
          }
      }
  });
  # note that the watcher might need about 1s to start up

=head1 IMPLEMENTATION

L<File::ChangeNotify> only supports blocking waits or polling as an
interface. This module creates a subprocess that blocks and communicates
the changes to the main process.

=head1 SEE ALSO

L<File::ChangeNotify> - the file watching implementation

=cut

has 'watcher';

sub _spawn_watcher( $self, $args ) {
    my $subprocess = Mojo::IOLoop::Subprocess->new();
    #use Data::Dumper; warn Dumper( File::ChangeNotify->usable_classes );
    $subprocess->run( sub( $subprocess ) {
        watch( $subprocess, $args );
        return () # return an empty list here to not return anything after the process ends
    }, sub ($subprocess, $err, @results ) {
        say "Subprocess error: $err" and return if $err;
        say "Surprising results: @results"
            if @results;
    }
    );
}

our %PIDs;

sub instantiate_watcher( $class, %args ) {
    my $handler = delete $args{ on_change };
    my $self = $class->new();
    if( $handler ) {
        $self->on( 'change' => $handler );
    }

    $self->watcher( $self->_spawn_watcher( \%args ));
    $self->watcher->on('spawn' => sub( $w ) {
        $PIDs{ $w->pid } = 1;
    });
    $self->watcher->on('progress' => sub( $w, $events ) {
        $self->emit('change' => $events )
    });
    #$self->watcher->on('cleanup' => sub( $w, $events ) {
    #    warn "Child gone (in child?)";
    #});

    return $self;
}

# Cleanup watchers when we are removed
sub DESTROY( $self ) {
    if( my $w = $self->watcher ) {
        my $pid = $w->pid;
        if( $pid ) {
            delete $PIDs{ $pid };
            kill KILL => $w->pid;
        }
    }
}

# Clean up watchers if we die for other reasons
END {
    kill KILL => keys %PIDs
}

1;
