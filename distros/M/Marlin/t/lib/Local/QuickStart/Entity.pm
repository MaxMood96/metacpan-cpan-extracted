package Local::QuickStart::Entity;

use v5.20;
use experimental 'signatures';
use Marlin;

sub as_hashref ( $self ) {
  return {
    id      => $self->id,
    name    => $self->name,
    status  => $self->status,
    retries => $self->retries,
  };
}

1;
