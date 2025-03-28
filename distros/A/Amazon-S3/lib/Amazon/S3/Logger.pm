package Amazon::S3::Logger;

use strict;
use warnings;

use Amazon::S3::Constants qw{ :chars };

use English qw{-no_match_vars};
use POSIX;
use Readonly;
use Scalar::Util qw{ reftype };

our $VERSION = '0.65'; ## no critic (RequireInterpolationOfMetachars)

Readonly::Hash our %LOG_LEVELS => (
  trace => 5,
  debug => 4,
  info  => 3,
  warn  => 2,
  error => 1,
  fatal => 0,
);

{
  no strict 'refs'; ## no critic (ProhibitNoStrict)

  foreach my $level (qw{fatal error warn info debug trace}) {

    *{ __PACKAGE__ . $DOUBLE_COLON . $level } = sub {
      my ( $self, @message ) = @_;
      $self->_log_message( $level, @message );
    };
  }
}

########################################################################
sub new {
########################################################################
  my ( $class, @args ) = @_;

  my $options = ref $args[0] ? $args[0] : {@args};

  return bless $options, $class;
}

########################################################################
sub level {
########################################################################
  my ( $self, @args ) = @_;

  if (@args) {
    $self->{log_level} = $args[0];
  }

  return $self->{log_level};
}

########################################################################
sub _log_message {
########################################################################
  my ( $self, $level, @message ) = @_;

  return if $LOG_LEVELS{ lc $level } > $LOG_LEVELS{ lc $self->{log_level} };
  return if !@message;

  my $log_message;

  if ( defined $message[0]
    && ref $message[0]
    && reftype( $message[0] ) eq 'CODE' ) {
    $log_message = $message[0]->();
  }
  else {
    $log_message = join $EMPTY, @message;
  }

  chomp $log_message;

  my @tm = localtime time;

  my $timestamp = POSIX::strftime '%Y/%m/%d %H:%M:%S', @tm;

  return print {*STDERR} sprintf qq{%s: %s %s %s\n}, uc $level, $timestamp,
    $PROCESS_ID, $log_message;
}

1;
