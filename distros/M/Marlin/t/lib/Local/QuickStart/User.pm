package Local::QuickStart::User;

use v5.20;
use Types::Common -types, -lexical;
use Marlin
  'username!' => NonEmptyStr,
  'email?'    => NonEmptyStr,
  'active'    => { isa => Bool, default => 1 };

1;
