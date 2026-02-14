package Local::QuickStart::Role::CanImpersonate;

use v5.20;
use experimental 'signatures';
use Marlin::Role;

sub can_impersonate ( $self ) {
  return 1;
}

1;
