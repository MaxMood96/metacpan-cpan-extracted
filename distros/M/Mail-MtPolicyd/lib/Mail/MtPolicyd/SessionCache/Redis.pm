package Mail::MtPolicyd::SessionCache::Redis;

use Moose;

our $VERSION = '2.05'; # VERSION
# ABSTRACT: a session cache adapter for redis

use Time::HiRes qw(usleep);
use Storable;

extends 'Mail::MtPolicyd::SessionCache::Base';

with 'Mail::MtPolicyd::Role::Connection' => {
  name => 'redis',
  type => 'Redis',
};


has 'expire' => ( is => 'ro', isa => 'Int', default => 5 * 60 );

has 'lock_wait' => ( is => 'rw', isa => 'Int', default => 50 );
has 'lock_max_retry' => ( is => 'rw', isa => 'Int', default => 50 );
has 'lock_timeout' => ( is => 'rw', isa => 'Int', default => 10 );

sub _acquire_session_lock {
	my ( $self, $instance ) = @_;
	my $lock = 'lock_'.$instance;

	for( my $try = 1 ; $try < $self->lock_max_retry ; $try++ ) {
		if( $self->_redis_handle->set($lock, 1, 'EX', $self->lock_timeout, 'NX' ) ) {
			return; # lock created
		}
		usleep( $self->lock_wait * $try );
	}

	die('could not acquire lock for session '.$instance);
	return;
}

sub _release_session_lock {
	my ( $self, $instance ) = @_;
	my $lock = 'lock_'.$instance;

	$self->_redis_handle->del($lock);

	return;
}

sub retrieve_session {
	my ($self, $instance ) = @_;

	if( ! defined $instance ) {
		return;
	}

	$self->_acquire_session_lock( $instance );

	if( my $blob = $self->_redis_handle->get($instance) ) {
    my $session;
    eval { $session = Storable::thaw( $blob ) };
    if( $@ ) {
      die("could not restore session $instance: $@");
    }
		return($session);
	}
	
	return( { '_instance' => $instance } );
}

sub store_session {
	my ($self, $session ) = @_;
	my $instance = $session->{'_instance'};

	if( ! defined $session || ! defined $instance ) {
		return;
	}
	
  my $data = Storable::freeze( $session );
	$self->_redis_handle->set($instance, $data, 'EX', $self->expire);

	$self->_release_session_lock($instance);

	return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mail::MtPolicyd::SessionCache::Redis - a session cache adapter for redis

=head1 VERSION

version 2.05

=head1 SYNOPSIS

  <SessionCache>
    module = "Redis"
    #redis = "redis"
    # expire session cache entries
    expire = "300"
    # wait timeout will be increased each time 50,100,150,... (usec)
    lock_wait=50
    # abort after n retries
    lock_max_retry=50
    # session lock times out after (sec)
    lock_timeout=10
  </SessionCache>

=head1 PARAMETERS

=over

=item redis (default: redis)

Name of the database connection to use.

You have to define this connection first.

see L<Mail::MtPolicyd::Connection::Redis>

=item expire (default: 5*60)

Timeout in seconds for sessions.

=item lock_wait (default: 50)

Timeout for retry when session is locked in milliseconds.

The retry will be done in multiples of this timeout.

When set to 50 retry will be done in 50, 100, 150ms...

=item lock_max_retry (default: 50)

Maximum number of retries before giving up to obtain lock on a
session.

=item lock_timeout (default: 10)

Timeout of session locks in seconds.

=back

=head1 AUTHOR

Markus Benning <ich@markusbenning.de>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Markus Benning <ich@markusbenning.de>.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
