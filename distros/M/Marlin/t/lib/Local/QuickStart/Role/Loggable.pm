package Local::QuickStart::Role::Loggable;

use v5.20;
use experimental 'signatures';
use Marlin::Role 'logs' => { default => [] };

sub log_debug ( $self, $msg ) {
  push @{ $self->logs }, $msg;
  return $self;
}

1;
