package Local::QuickStart::Event;

use v5.20;
use Types::Common -types, -lexical;
use Marlin
  'id!'        => Int,
  'kind!'      => Enum[qw(create update delete)],
  'payload'    => { isa => HashRef, default => {} },
  'created_at' => { isa => Int, default => sub { time } },
  'tags'       => { isa => ArrayRef[Str], default => [] };

1;
