use Test2::V0;
use Test2::Require::Perl 'v5.20';

use lib 'lib', 't/lib';
use Local::QuickStart::Model::Admin;

my $a = Local::QuickStart::Model::Admin->new(
  username    => 'admin',
  permissions => 'all',
  created_by  => 'root',
);

is( $a->username, 'admin', 'inherited attribute works' );
is( $a->permissions, 'all', 'local required attribute works' );
ok( $a->DOES('Local::QuickStart::Role::Auditable'), 'role consumed' );
ok(
  $a->DOES('Local::QuickStart::Role::CanImpersonate'),
  'second role consumed',
);
ok( $a->can_impersonate, 'role method works' );
ok( !$a->has_updated_by, 'role predicate works' );

done_testing;
