use Test2::V0;
use Test2::Require::Perl 'v5.20';

use lib 'lib', 't/lib';
use Local::QuickStart::Event;

my $e1 = Local::QuickStart::Event->new(
  id   => 1,
  kind => 'create',
);
my $e2 = Local::QuickStart::Event->new(
  id   => 2,
  kind => 'create',
);

is( $e1->payload, {}, 'default hashref value exists' );
is( $e1->tags, [], 'default arrayref value exists' );
ok( $e1->payload != $e2->payload, 'empty hashref defaults are cloned' );
ok( $e1->tags != $e2->tags, 'empty arrayref defaults are cloned' );

ok(
  dies { Local::QuickStart::Event->new( id => 3, kind => 'oops' ) },
  'enum type check works',
);

done_testing;
