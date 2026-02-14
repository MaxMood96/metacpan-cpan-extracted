package Local::QuickStart::Model::Admin;

use v5.20;
use Marlin
  qw( permissions! audit_log? ),
  -extends => 'Local::QuickStart::User',
  -with    => [
    'Local::QuickStart::Role::CanImpersonate',
    'Local::QuickStart::Role::Auditable',
  ];

1;
