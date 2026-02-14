package Local::QuickStart::Job;

use v5.20;
use experimental 'signatures';
use Types::Common -types, -lexical;
use Marlin::Util qw( true false );
use Marlin
  'id!'          => Int,
  'name!'        => Str,
  'status=?'     => {
    isa     => Enum[qw(pending running done failed)],
    default => 'pending',
  },
  'retries='     => { isa => Int, default => 0 },
  'max_retries'  => { isa => Int, default => 3 },
  'metadata'     => { isa => HashRef, default => {} },
  'warnings'     => {
    isa         => ArrayRef[Str],
    default     => [],
    handles_via => 'Array',
    handles     => { add_warning => 'push' },
  },
  'finished_at=' => { isa => Maybe[Int] },
  -extends       => 'Local::QuickStart::Entity',
  -with          => [
    'Local::QuickStart::Role::Loggable',
    'Local::QuickStart::Role::Serializable',
  ],
  -modifiers;

before run => sub ( $self ) {
  $self->log_debug('starting run');
};

sub run ( $self ) {
  return 'ok';
}

around as_hashref => sub ( $next, $self ) {
  my $h = $self->$next;
  $h->{status} = uc $h->{status};
  return $h;
};

1;
